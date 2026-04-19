import SwiftUI

struct ChatProvider: PanelProvider {
    static let scheme = "chat"
    static let displayName = "Claude Chat"

    let keychain: KeychainStore

    func makeView(for source: PanelSource, context: PanelContext) -> AnyView {
        AnyView(ChatPanelView(source: source, context: context, keychain: keychain))
    }
}
