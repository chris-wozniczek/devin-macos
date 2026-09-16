import SwiftUI

struct PlacementView: View {
    let controller: MatchController

    @State private var board: Board
    @State private var selected: ShipKind?
    @State private var orientation: Orientation = .horizontal
    @State private var shake = 0

    init(controller: MatchController) {
        self.controller = controller
        _board = State(initialValue: controller.myBoard)
    }

    private var waiting: Bool { controller.phase == .awaitingOpponent }

    var body: some View {
        VStack(spacing: 14) {
            header
            BoardGridView(mark: mark, highlight: nil, interactive: !waiting, onTap: tapped)
                .padding(.horizontal, 6)
                .modifier(ShakeEffect(shakes: shake))
            fleetDock
            controls
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onChange(of: controller.myBoard.ships) { _, ships in
            if waiting == false && ships != board.ships { board = controller.myBoard }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            StencilText("Deploy Fleet", size: 26)
            Text(waiting
                 ? "Standing by for \(controller.opponentName)..."
                 : (selected.map { "Tap the grid to place the \($0.displayName.lowercased())" } ?? "Select a ship, or tap a placed ship to move it"))
                .font(.typewriter(13))
                .foregroundStyle(Theme.khaki)
                .multilineTextAlignment(.center)
                .frame(height: 34)
        }
        .padding(.top, 8)
    }

    private var fleetDock: some View {
        RivetedPanel {
            VStack(spacing: 8) {
                ForEach(Board.fleet) { kind in
                    let placed = board.ship(of: kind) != nil
                    Button {
                        guard !waiting else { return }
                        if selected == kind {
                            selected = nil
                        } else {
                            selected = kind
                            if let ship = board.ship(of: kind) { orientation = ship.orientation }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: kind.symbol)
                                .frame(width: 22)
                                .foregroundStyle(selected == kind ? Theme.brass : Theme.khaki)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.displayName.uppercased())
                                    .font(.stencil(13)).kerning(1)
                                Text(kind.designation)
                                    .font(.typewriter(10))
                                    .foregroundStyle(Theme.khaki.opacity(0.7))
                            }
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(0..<kind.length, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(placed ? Theme.hull : Theme.steel.opacity(0.5))
                                        .frame(width: 12, height: 12)
                                }
                            }
                            Image(systemName: placed ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(placed ? Theme.victory : Theme.steel)
                                .frame(width: 22)
                        }
                        .foregroundStyle(Theme.paper)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected == kind ? Theme.brass.opacity(0.18) : .clear)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                CommandButton(title: orientation == .horizontal ? "Horizontal" : "Vertical",
                              icon: "rotate.right", style: .secondary) {
                    rotate()
                }
                CommandButton(title: "Shuffle", icon: "shuffle", style: .secondary) {
                    withAnimation(.spring(duration: 0.4)) { board = Board.random() }
                    selected = nil
                }
            }
            .disabled(waiting)
            .opacity(waiting ? 0.5 : 1)

            if waiting {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.brass)
                    Text("AWAITING ENEMY FLEET")
                        .font(.stencil(14)).kerning(1.5)
                        .foregroundStyle(Theme.brass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.brass.opacity(0.5), lineWidth: 1.5)
                }
            } else {
                CommandButton(title: "Battle Stations", icon: "flag.fill") {
                    controller.setBoard(board)
                    controller.confirmFleet()
                }
                .disabled(!board.isComplete)
                .opacity(board.isComplete ? 1 : 0.45)
            }
        }
    }

    private func mark(_ c: Coordinate) -> CellMark {
        if let ship = board.ship(at: c) {
            return .ship(ship.kind, sunk: false)
        }
        return .water
    }

    private func tapped(_ c: Coordinate) {
        if let kind = selected {
            let ship = Ship(kind: kind, bow: c, orientation: orientation)
            if board.canPlace(ship) {
                withAnimation(.spring(duration: 0.3)) { board.place(ship) }
                selected = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                withAnimation(.default) { shake += 1 }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } else if let ship = board.ship(at: c) {
            selected = ship.kind
            orientation = ship.orientation
            withAnimation(.spring(duration: 0.25)) { board.remove(ship.kind) }
        }
    }

    private func rotate() {
        orientation = orientation.toggled
        guard let kind = selected, let ship = board.ship(of: kind) else { return }
        var rotated = ship
        rotated.orientation = orientation
        if board.canPlace(rotated, ignoring: ship) {
            withAnimation(.spring(duration: 0.3)) { board.place(rotated) }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    init(shakes: Int) { animatableData = CGFloat(shakes) }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 6) * 6, y: 0))
    }
}
