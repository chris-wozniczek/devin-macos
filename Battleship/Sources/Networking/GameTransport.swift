import Foundation

/// Wire protocol shared by every transport. Both players run identical state machines,
/// so the only messages needed are the ready handshake, shots and their results.
enum GameMessage: Codable {
    /// Fleet is placed. `seed` decides who fires first (higher seed opens fire).
    case ready(seed: UInt64, name: String)
    case fire(Coordinate)
    case result(ShotResult)
    case rematch
    case leave

    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) throws -> GameMessage { try JSONDecoder().decode(GameMessage.self, from: data) }
}

enum TransportKind: String {
    case gameCenter = "Game Center"
    case nearby = "Nearby"
    case practice = "Practice"
}

@MainActor
protocol GameTransport: AnyObject {
    var kind: TransportKind { get }
    var opponentName: String { get }
    var onMessage: ((GameMessage) -> Void)? { get set }
    var onDisconnect: (() -> Void)? { get set }
    func send(_ message: GameMessage)
    func disconnect()
}
