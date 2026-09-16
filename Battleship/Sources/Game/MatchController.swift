import Foundation
import Observation
import UIKit

struct BattleEvent: Identifiable, Equatable {
    enum Kind: Equatable { case info, hit, miss, sunk, victory, defeat }
    let id = UUID()
    let kind: Kind
    let text: String
}

@MainActor
@Observable
final class MatchController {
    enum Phase: Equatable {
        case placement
        case awaitingOpponent
        case battle
        case finished(victory: Bool)
        case opponentLeft
    }

    private(set) var phase: Phase = .placement
    private(set) var myBoard = Board()
    private(set) var enemyShots: [Coordinate: ShotResult] = [:]
    private(set) var sunkEnemyShips: [ShipKind] = []
    private(set) var sunkEnemyCells: Set<Coordinate> = []
    private(set) var isMyTurn = false
    private(set) var awaitingResult = false
    private(set) var events: [BattleEvent] = []
    private(set) var lastEnemyShot: Coordinate?
    private(set) var lastMyShot: ShotResult?
    private(set) var rematchRequested = false
    private(set) var opponentWantsRematch = false
    private(set) var round = 1
    var opponentReady: Bool { opponentSeed != nil }

    let transport: GameTransport
    let playerName: String
    var opponentName: String { opponentDisplayName ?? transport.opponentName }

    private var mySeed: UInt64 = 0
    private var opponentSeed: UInt64?
    private var opponentDisplayName: String?

    var shotsFired: Int { enemyShots.count }
    var shotsHit: Int { enemyShots.values.filter(\.hit).count }
    var accuracy: Double { shotsFired == 0 ? 0 : Double(shotsHit) / Double(shotsFired) }

    init(transport: GameTransport, playerName: String) {
        self.transport = transport
        self.playerName = playerName
        transport.onMessage = { [weak self] message in self?.handle(message) }
        transport.onDisconnect = { [weak self] in
            guard let self else { return }
            if case .finished = self.phase { return }
            self.phase = .opponentLeft
        }
        myBoard = Board.random()
        log(.info, "Awaiting orders, Admiral. Position your fleet.")
    }

    // MARK: Placement

    func setBoard(_ board: Board) {
        guard phase == .placement else { return }
        myBoard = board
    }

    func randomizeFleet() {
        guard phase == .placement else { return }
        myBoard = Board.random()
    }

    func confirmFleet() {
        guard phase == .placement, myBoard.isComplete else { return }
        mySeed = UInt64.random(in: 1...UInt64.max)
        phase = .awaitingOpponent
        transport.send(.ready(seed: mySeed, name: playerName))
        log(.info, "Fleet deployed. Waiting for the enemy to take position...")
        startIfReady()
    }

    private func startIfReady() {
        guard phase == .awaitingOpponent, let opponentSeed else { return }
        phase = .battle
        isMyTurn = mySeed > opponentSeed
        log(.info, isMyTurn ? "Contact! You have the first salvo." : "Contact! \(opponentName) opens fire.")
        haptic(.medium)
    }

    // MARK: Battle

    func canFire(at coordinate: Coordinate) -> Bool {
        phase == .battle && isMyTurn && !awaitingResult && enemyShots[coordinate] == nil
    }

    func fire(at coordinate: Coordinate) {
        guard canFire(at: coordinate) else { return }
        awaitingResult = true
        transport.send(.fire(coordinate))
    }

    private func handle(_ message: GameMessage) {
        switch message {
        case let .ready(seed, name):
            opponentSeed = seed
            opponentDisplayName = name
            startIfReady()

        case let .fire(coordinate):
            guard phase == .battle else { return }
            let result = myBoard.receiveShot(at: coordinate)
            lastEnemyShot = coordinate
            transport.send(.result(result))
            if let sunk = result.sunk {
                log(.sunk, "\(sunk.displayName) \(sunk.designation) has been sunk!")
                haptic(.heavy)
            } else if result.hit {
                log(.hit, "We're hit at \(coordinate)!")
                haptic(.rigid)
            } else {
                log(.miss, "Enemy shell splashes at \(coordinate).")
            }
            if myBoard.allSunk {
                finish(victory: false)
            } else {
                isMyTurn = true
            }

        case let .result(result):
            guard phase == .battle else { return }
            awaitingResult = false
            enemyShots[result.coordinate] = result
            lastMyShot = result
            if let sunk = result.sunk {
                sunkEnemyShips.append(sunk)
                sunkEnemyCells.formUnion(result.sunkCells)
                log(.sunk, "Enemy \(sunk.displayName.lowercased()) sunk at \(result.coordinate)!")
                haptic(.heavy)
            } else if result.hit {
                log(.hit, "Direct hit at \(result.coordinate)!")
                haptic(.medium)
            } else {
                log(.miss, "Miss at \(result.coordinate).")
                haptic(.light)
            }
            if sunkEnemyShips.count == Board.fleet.count {
                finish(victory: true)
            } else {
                isMyTurn = false
            }

        case .rematch:
            opponentWantsRematch = true
            resetIfBothWantRematch()

        case .leave:
            if case .finished = phase { return }
            phase = .opponentLeft
        }
    }

    private func finish(victory: Bool) {
        phase = .finished(victory: victory)
        isMyTurn = false
        log(victory ? .victory : .defeat,
            victory ? "Enemy fleet destroyed. Victory at sea!" : "Our fleet has gone down. The enemy holds the seas.")
        haptic(.heavy)
    }

    // MARK: Rematch / leave

    func requestRematch() {
        guard case .finished = phase, !rematchRequested else { return }
        rematchRequested = true
        transport.send(.rematch)
        resetIfBothWantRematch()
    }

    private func resetIfBothWantRematch() {
        guard rematchRequested, opponentWantsRematch else { return }
        myBoard = Board.random()
        enemyShots = [:]
        sunkEnemyShips = []
        sunkEnemyCells = []
        isMyTurn = false
        awaitingResult = false
        lastEnemyShot = nil
        lastMyShot = nil
        rematchRequested = false
        opponentWantsRematch = false
        opponentSeed = nil
        events = []
        round += 1
        phase = .placement
        log(.info, "Rematch! Reposition your fleet.")
    }

    func leave() {
        transport.send(.leave)
        transport.disconnect()
    }

    // MARK: Helpers

    private func log(_ kind: BattleEvent.Kind, _ text: String) {
        events.insert(BattleEvent(kind: kind, text: text), at: 0)
        if events.count > 40 { events.removeLast() }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
