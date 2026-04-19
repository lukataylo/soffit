import MarkdownUI
import SwiftUI

struct ChatPanelView: View {
    let source: PanelSource
    let context: PanelContext
    let keychain: KeychainStore

    @StateObject private var model: ChatPanelModel
    @FocusState private var composerFocused: Bool

    init(source: PanelSource, context: PanelContext, keychain: KeychainStore) {
        self.source = source
        self.context = context
        self.keychain = keychain
        _model = StateObject(wrappedValue: ChatPanelModel(panelID: source.panelID, context: context, keychain: keychain))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(model.messages) { message in
                            ChatMessageBubble(message: message).id(message.id)
                        }
                        if model.isStreaming {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("Claude is thinking…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }.padding(.leading, 14)
                        }
                        if let err = model.error {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 14)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .onChange(of: model.messages.count) { _, _ in
                    if let last = model.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .onChange(of: model.streamingText) { _, _ in
                    if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            Divider()
            Composer(draft: $model.draft, isStreaming: model.isStreaming, onSend: { Task { await model.send() } }, focused: $composerFocused)
        }
        .onAppear {
            model.restore()
            composerFocused = true
        }
        .onDisappear { model.persist() }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(message.role == .user ? "You" : "Claude")
                .font(.caption.bold())
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(message.role == .user ? Color.accentColor : Color.purple)
            Markdown(message.content)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
    }
}

private struct Composer: View {
    @Binding var draft: String
    let isStreaming: Bool
    let onSend: () -> Void
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $draft)
                .font(.system(size: 13))
                .frame(minHeight: 40, maxHeight: 120)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .focused($focused)
                .onSubmit(onSend)

            Button {
                onSend()
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming)
        }
        .padding(10)
    }
}
