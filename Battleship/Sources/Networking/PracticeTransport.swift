import Foundation

/// A local opponent that speaks the same wire protocol as a remote player.
/// Uses a hunt/target strategy: random parity search until a hit, then probes neighbours.
@MainActor
final class PracticeTransport: GameTransport {
    let kind: TransportKind = .practice
    let opponentName = "Admiral Yamamoto"
    var onMessage: ((GameMessage) -> Void)?
    var onDisconnect: (() -> Void)?

    private var board = Board.random()
    private var fired: Set<Coordinate> = []
    private var targets: [Coordinate] = []
    private var pendingShot: Coordinate?
    private var seed: UInt64 = 0
    private var humanReady = false
    private var connected = true

    func send(_ message: GameMessage) {
        guard connected else { return }
        switch message {
        case .ready:
            humanReady = true
            seed = UInt64.random(in: 1...UInt64.max)
            board = Board.random()
            fired = []
            targets = []
            after(0.6) { [self] in
                onMessage?(.ready(seed: seed, name: opponentName))
                // The engine decides who opens fire from the seeds; if the AI has the
                // higher seed it must take the first shot itself.
                if seed > lastHumanSeed { fireNext() }
            }
            if case let .ready(humanSeed, _) = message { lastHumanSeed = humanSeed }

        case let .fire(coordinate):
            let result = board.receiveShot(at: coordinate)
            after(0.5) { [self] in
                onMessage?(.result(result))
                if !board.allSunk { fireNext() }
            }

        case let .result(result):
            handleResult(result)

        case .rematch:
            after(0.8) { [self] in onMessage?(.rematch) }

        case .leave:
            connected = false
        }
    }

    private var lastHumanSeed: UInt64 = 0

    func disconnect() { connected = false }

    // MARK: Strategy

    private func fireNext() {
        after(0.9) { [self] in
            guard connected else { return }
            let shot = chooseShot()
            pendingShot = shot
            fired.insert(shot)
            onMessage?(.fire(shot))
        }
    }

    private func chooseShot() -> Coordinate {
        while let candidate = targets.popLast() {
            if !fired.contains(candidate) { return candidate }
        }
        let all = (0..<Board.size).flatMap { r in (0..<Board.size).map { c in Coordinate(row: r, col: c) } }
        let open = all.filter { !fired.contains($0) }
        let parity = open.filter { ($0.row + $0.col) % 2 == 0 }
        return (parity.isEmpty ? open : parity).randomElement() ?? open[0]
    }

    private func handleResult(_ result: ShotResult) {
        guard result.hit else { return }
        if result.sunk != nil {
            targets.removeAll()
            return
        }
        let c = result.coordinate
        let neighbours = [c.offset(dr: -1, dc: 0), c.offset(dr: 1, dc: 0), c.offset(dr: 0, dc: -1), c.offset(dr: 0, dc: 1)]
        for n in neighbours where n.isValid && !fired.contains(n) && !targets.contains(n) {
            targets.append(n)
        }
    }

    private func after(_ seconds: Double, _ block: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            block()
        }
    }
}
