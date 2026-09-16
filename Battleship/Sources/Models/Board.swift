import Foundation

struct Coordinate: Hashable, Codable, CustomStringConvertible {
    var row: Int
    var col: Int

    var isValid: Bool { (0..<Board.size).contains(row) && (0..<Board.size).contains(col) }

    var description: String {
        let letter = Character(UnicodeScalar(UInt8(65 + row)))
        return "\(letter)\(col + 1)"
    }

    func offset(dr: Int, dc: Int) -> Coordinate { Coordinate(row: row + dr, col: col + dc) }
}

enum Orientation: String, Codable {
    case horizontal, vertical

    var toggled: Orientation { self == .horizontal ? .vertical : .horizontal }
}

enum ShipKind: String, CaseIterable, Codable, Identifiable {
    case carrier, battleship, cruiser, submarine, destroyer

    var id: String { rawValue }

    var length: Int {
        switch self {
        case .carrier: 5
        case .battleship: 4
        case .cruiser: 3
        case .submarine: 3
        case .destroyer: 2
        }
    }

    var displayName: String {
        switch self {
        case .carrier: "Carrier"
        case .battleship: "Battleship"
        case .cruiser: "Cruiser"
        case .submarine: "Submarine"
        case .destroyer: "Destroyer"
        }
    }

    /// Hull designation shown in the fleet roster, in the style of WW2 US Navy vessels.
    var designation: String {
        switch self {
        case .carrier: "CV-6 Enterprise"
        case .battleship: "BB-61 Iowa"
        case .cruiser: "CA-35 Indianapolis"
        case .submarine: "SS-238 Wahoo"
        case .destroyer: "DD-537 The Sullivans"
        }
    }

    var symbol: String {
        switch self {
        case .carrier: "airplane"
        case .battleship: "shield.lefthalf.filled"
        case .cruiser: "ferry.fill"
        case .submarine: "water.waves"
        case .destroyer: "bolt.fill"
        }
    }
}

struct Ship: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: ShipKind
    var bow: Coordinate
    var orientation: Orientation

    init(kind: ShipKind, bow: Coordinate, orientation: Orientation) {
        self.id = UUID()
        self.kind = kind
        self.bow = bow
        self.orientation = orientation
    }

    var coordinates: [Coordinate] {
        (0..<kind.length).map { i in
            orientation == .horizontal ? bow.offset(dr: 0, dc: i) : bow.offset(dr: i, dc: 0)
        }
    }

    var isInBounds: Bool { coordinates.allSatisfy(\.isValid) }
}

struct ShotResult: Codable, Hashable {
    let coordinate: Coordinate
    let hit: Bool
    let sunk: ShipKind?
    /// Every cell of the sunk ship, so the attacker can mark the whole hull.
    let sunkCells: [Coordinate]

    init(coordinate: Coordinate, hit: Bool, sunk: ShipKind? = nil, sunkCells: [Coordinate] = []) {
        self.coordinate = coordinate
        self.hit = hit
        self.sunk = sunk
        self.sunkCells = sunkCells
    }
}

struct Board {
    static let size = 10
    static let fleet: [ShipKind] = ShipKind.allCases

    var ships: [Ship] = []
    /// Shots the opponent has fired at this board.
    var shots: Set<Coordinate> = []

    var isComplete: Bool { ships.count == Board.fleet.count }
    var unplacedKinds: [ShipKind] { Board.fleet.filter { kind in !ships.contains { $0.kind == kind } } }

    func ship(at coordinate: Coordinate) -> Ship? {
        ships.first { $0.coordinates.contains(coordinate) }
    }

    func ship(of kind: ShipKind) -> Ship? { ships.first { $0.kind == kind } }

    func canPlace(_ ship: Ship, ignoring ignored: Ship? = nil) -> Bool {
        guard ship.isInBounds else { return false }
        let occupied = Set(ships.filter { $0.id != ignored?.id && $0.kind != ship.kind }.flatMap(\.coordinates))
        return ship.coordinates.allSatisfy { !occupied.contains($0) }
    }

    @discardableResult
    mutating func place(_ ship: Ship) -> Bool {
        guard canPlace(ship) else { return false }
        ships.removeAll { $0.kind == ship.kind }
        ships.append(ship)
        return true
    }

    mutating func remove(_ kind: ShipKind) {
        ships.removeAll { $0.kind == kind }
    }

    func hits(on ship: Ship) -> Int { ship.coordinates.filter { shots.contains($0) }.count }
    func isSunk(_ ship: Ship) -> Bool { hits(on: ship) == ship.kind.length }
    var allSunk: Bool { isComplete && ships.allSatisfy(isSunk) }

    mutating func receiveShot(at coordinate: Coordinate) -> ShotResult {
        shots.insert(coordinate)
        guard let ship = ship(at: coordinate) else {
            return ShotResult(coordinate: coordinate, hit: false, sunk: nil)
        }
        let sunk = isSunk(ship)
        return ShotResult(coordinate: coordinate, hit: true, sunk: sunk ? ship.kind : nil, sunkCells: sunk ? ship.coordinates : [])
    }

    static func random(using generator: inout some RandomNumberGenerator) -> Board {
        var board = Board()
        for kind in fleet {
            var attempts = 0
            while attempts < 500 {
                attempts += 1
                let orientation: Orientation = Bool.random(using: &generator) ? .horizontal : .vertical
                let bow = Coordinate(row: Int.random(in: 0..<size, using: &generator),
                                     col: Int.random(in: 0..<size, using: &generator))
                if board.place(Ship(kind: kind, bow: bow, orientation: orientation)) { break }
            }
        }
        return board
    }

    static func random() -> Board {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }
}
