import Foundation

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, assistant, system }
    var id: UUID = UUID()
    var role: Role
    var content: String
}

struct ChatState: Codable {
    var messages: [ChatMessage] = []
}

@MainActor
final class ChatPanelModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isStreaming: Bool = false
    @Published var streamingText: String = ""
    @Published var error: String?

    private let panelID: PanelID
    private let context: PanelContext
    private let keychain: KeychainStore
    private var streamTask: Task<Void, Never>?
    private var restored = false

    init(panelID: PanelID, context: PanelContext, keychain: KeychainStore) {
        self.panelID = panelID
        self.context = context
        self.keychain = keychain
    }

    func restore() {
        guard !restored else { return }
        restored = true
        guard let data = currentStateData(),
              let state = try? JSONDecoder().decode(ChatState.self, from: data) else { return }
        messages = state.messages
    }

    func persist() {
        let state = ChatState(messages: messages)
        let data = try? JSONEncoder().encode(state)
        context.savePanelState(panelID, data)
    }

    func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }
        guard let key = keychain.apiKey, !key.isEmpty else {
            error = "No Anthropic API key. Set one via the onboarding prompt."
            return
        }
        error = nil
        draft = ""
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        persist()

        var assistant = ChatMessage(role: .assistant, content: "")
        messages.append(assistant)
        isStreaming = true

        let history = messages.dropLast().map { $0 }
        let client = AnthropicClient(apiKey: key)

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try await client.stream(messages: history, model: "claude-opus-4-7")
                for try await chunk in stream {
                    await MainActor.run {
                        assistant.content += chunk
                        if !self.messages.isEmpty { self.messages[self.messages.count - 1] = assistant }
                        self.streamingText = assistant.content
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Stream failed: \(error.localizedDescription)"
                    if !self.messages.isEmpty, self.messages.last?.role == .assistant, self.messages.last?.content.isEmpty == true {
                        self.messages.removeLast()
                    }
                }
            }
            await MainActor.run {
                self.isStreaming = false
                self.persist()
            }
        }
    }

    private func currentStateData() -> Data? {
        // State flows through opaque Data, delivered via the tree snapshot captured at panel creation.
        // For simplicity v0.1 keeps chat history in memory and persists on each send/close via savePanelState.
        // To cold-start, the app stores the last-persisted state blob inline in the LayoutTree, and that
        // blob is accessible via panel.state at render time. We expose a restore hook below that reads it.
        InitialStateHolder.shared.read(panelID)
    }
}

/// Holds the last-seen initial panel state keyed by panel ID so chat panels can restore history on appear.
final class InitialStateHolder {
    static let shared = InitialStateHolder()
    private let lock = NSLock()
    private var store: [PanelID: Data] = [:]

    func write(_ id: PanelID, _ data: Data?) {
        lock.lock(); defer { lock.unlock() }
        if let data { store[id] = data } else { store.removeValue(forKey: id) }
    }

    func read(_ id: PanelID) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return store[id]
    }
}
