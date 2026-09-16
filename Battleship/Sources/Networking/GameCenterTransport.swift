import Foundation
import GameKit
import SwiftUI

/// Online play over a Game Center real-time match (`GKMatch`).
@MainActor
final class GameCenterTransport: NSObject, GameTransport, GKMatchDelegate {
    let kind: TransportKind = .gameCenter
    var onMessage: ((GameMessage) -> Void)?
    var onDisconnect: (() -> Void)?

    private let match: GKMatch

    var opponentName: String { match.players.first?.displayName ?? "Opponent" }

    init(match: GKMatch) {
        self.match = match
        super.init()
        match.delegate = self
    }

    private var queued: [GameMessage] = []

    /// Messages sent before the remote player finishes connecting are held back.
    func send(_ message: GameMessage) {
        guard match.expectedPlayerCount == 0 else {
            queued.append(message)
            return
        }
        do {
            try match.sendData(toAllPlayers: try message.encoded(), with: .reliable)
        } catch {
            onDisconnect?()
        }
    }

    private func flushQueue() {
        let pending = queued
        queued = []
        pending.forEach(send)
    }

    func disconnect() {
        match.delegate = nil
        match.disconnect()
    }

    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = try? GameMessage.decode(data) else { return }
        Task { @MainActor in self.onMessage?(message) }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            switch state {
            case .connected: self.flushQueue()
            case .disconnected: self.onDisconnect?()
            default: break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor in self.onDisconnect?() }
    }
}

/// Handles Game Center sign-in and exposes the state to SwiftUI.
@MainActor
@Observable
final class GameCenterSession {
    enum State: Equatable { case unknown, authenticating, authenticated(alias: String), unavailable(String) }
    private(set) var state: State = .unknown

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    var alias: String {
        if case let .authenticated(alias) = state { return alias }
        return UIDevice.current.name
    }

    func authenticate() {
        guard state == .unknown || { if case .unavailable = state { return true } else { return false } }() else { return }
        state = .authenticating
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    self.state = .authenticated(alias: GKLocalPlayer.local.displayName)
                } else {
                    self.state = .unavailable(error?.localizedDescription ?? "Game Center is not available on this device.")
                }
            }
        }
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

/// Wraps `GKMatchmakerViewController` so a 1v1 real-time match can be requested from SwiftUI.
struct GameCenterMatchmakerView: UIViewControllerRepresentable {
    let onMatch: (GKMatch) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> GKMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Battle stations! Join me for a game of Battleship."
        let controller = GKMatchmakerViewController(matchRequest: request)!
        controller.matchmakerDelegate = context.coordinator
        controller.matchmakingMode = .default
        return controller
    }

    func updateUIViewController(_ uiViewController: GKMatchmakerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onMatch: onMatch, onCancel: onCancel) }

    final class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let onMatch: (GKMatch) -> Void
        let onCancel: () -> Void

        init(onMatch: @escaping (GKMatch) -> Void, onCancel: @escaping () -> Void) {
            self.onMatch = onMatch
            self.onCancel = onCancel
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            onMatch(match)
        }
    }
}
