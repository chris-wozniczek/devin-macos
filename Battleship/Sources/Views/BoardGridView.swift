import SwiftUI

enum CellMark: Equatable {
    case water
    case ship(ShipKind, sunk: Bool)
    case hit(sunk: Bool)
    case miss
    case preview(valid: Bool)
}

/// 10x10 ocean grid with A–J / 1–10 labels. Rendering of each cell is driven by `mark`.
struct BoardGridView: View {
    let mark: (Coordinate) -> CellMark
    var highlight: Coordinate? = nil
    var showLabels: Bool = true
    var interactive: Bool = true
    var onTap: ((Coordinate) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let labelSize: CGFloat = showLabels ? max(12, geo.size.width * 0.055) : 0
            let side = min(geo.size.width, geo.size.height) - labelSize
            let cell = side / CGFloat(Board.size)

            VStack(spacing: 0) {
                if showLabels {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: labelSize, height: labelSize)
                        ForEach(0..<Board.size, id: \.self) { col in
                            Text("\(col + 1)")
                                .font(.typewriter(labelSize * 0.62, weight: .bold))
                                .foregroundStyle(Theme.khaki.opacity(0.8))
                                .frame(width: cell, height: labelSize)
                        }
                    }
                }
                ForEach(0..<Board.size, id: \.self) { row in
                    HStack(spacing: 0) {
                        if showLabels {
                            Text(String(Character(UnicodeScalar(UInt8(65 + row)))))
                                .font(.typewriter(labelSize * 0.62, weight: .bold))
                                .foregroundStyle(Theme.khaki.opacity(0.8))
                                .frame(width: labelSize, height: cell)
                        }
                        ForEach(0..<Board.size, id: \.self) { col in
                            let coordinate = Coordinate(row: row, col: col)
                            CellView(mark: mark(coordinate), size: cell, highlighted: highlight == coordinate)
                                .contentShape(Rectangle())
                                .allowsHitTesting(interactive)
                                .onTapGesture { onTap?(coordinate) }
                        }
                    }
                }
            }
            .frame(width: side + labelSize, height: side + labelSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CellView: View {
    let mark: CellMark
    let size: CGFloat
    let highlighted: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(fill)
                .overlay {
                    Rectangle().strokeBorder(Theme.miss.opacity(0.18), lineWidth: 0.5)
                }
            content
            if highlighted {
                Rectangle()
                    .strokeBorder(Theme.brass, lineWidth: 2)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: mark)
    }

    private var fill: Color {
        switch mark {
        case .water: Theme.sea.opacity(0.55)
        case let .ship(_, sunk): sunk ? Theme.hit.opacity(0.35) : Theme.hull.opacity(0.9)
        case let .hit(sunk): sunk ? Theme.hit.opacity(0.9) : Theme.hit.opacity(0.55)
        case .miss: Theme.sea.opacity(0.55)
        case let .preview(valid): valid ? Theme.victory.opacity(0.5) : Theme.hit.opacity(0.5)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mark {
        case .water, .preview:
            EmptyView()
        case let .ship(kind, sunk):
            if sunk {
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(Theme.ember)
            } else {
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Theme.navy.opacity(0.6))
            }
        case let .hit(sunk):
            Image(systemName: sunk ? "flame.fill" : "xmark")
                .font(.system(size: size * 0.6, weight: .black))
                .foregroundStyle(sunk ? Theme.ember : Theme.paper)
                .shadow(color: Theme.ember.opacity(0.8), radius: 4)
                .transition(.scale(scale: 2).combined(with: .opacity))
        case .miss:
            Circle()
                .fill(Theme.miss.opacity(0.7))
                .frame(width: size * 0.3, height: size * 0.3)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
        }
    }
}

extension Board {
    /// Marks for the player's own board (ships visible).
    func ownMark(at c: Coordinate) -> CellMark {
        if let ship = ship(at: c) {
            let sunk = isSunk(ship)
            return shots.contains(c) ? .hit(sunk: sunk) : .ship(ship.kind, sunk: sunk)
        }
        return shots.contains(c) ? .miss : .water
    }
}
