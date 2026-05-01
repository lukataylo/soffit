import Combine
import Foundation
import SwiftUI

struct PanelSource {
    let url: URL?
    let panelID: PanelID
}

final class PanelNotificationBus {
    private let subject = PassthroughSubject<PanelEvent, Never>()

    var publisher: AnyPublisher<PanelEvent, Never> { subject.eraseToAnyPublisher() }
    func send(_ event: PanelEvent) { subject.send(event) }
}

struct PanelEvent {
    let origin: PanelID?
    let name: String
    let payload: [String: String]
}

struct PanelContext {
    let workspaceRoot: URL?
    let keychain: KeychainStore
    let notifications: PanelNotificationBus
    let savePanelState: (PanelID, Data?) -> Void
}

protocol PanelProvider {
    static var scheme: String { get }
    static var displayName: String { get }
    func makeView(for source: PanelSource, context: PanelContext) -> AnyView
    func initialPanel(source: String, title: String?) -> Panel
}

extension PanelProvider {
    func initialPanel(source: String, title: String?) -> Panel {
        Panel(source: source, title: title ?? Self.displayName)
    }
}

@MainActor
final class ProviderRegistry: ObservableObject {
    private var providers: [String: any PanelProvider] = [:]

    func register<P: PanelProvider>(_ provider: P) {
        providers[P.scheme] = provider
    }

    func register<P: PanelProvider>(_ provider: P, forScheme scheme: String) {
        providers[scheme] = provider
    }

    func provider(for panel: Panel) -> (any PanelProvider)? {
        providers[panel.scheme]
    }

    func provider(forScheme scheme: String) -> (any PanelProvider)? {
        providers[scheme]
    }

    var schemes: [String] { Array(providers.keys).sorted() }
}
