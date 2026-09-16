import SwiftUI

struct BattleView: View {
    let controller: MatchController
    @State private var showOwnBoard = false
    @State private var pendingTarget: Coordinate?

    var body: some View {
        VStack(spacing: 12) {
            turnBanner
            targetGrid
            eventTicker
            fleetStatus
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .sheet(isPresented: $showOwnBoard) { ownBoardSheet }
        .onChange(of: controller.lastMyShot) { _, _ in pendingTarget = nil }
    }

    // MARK: Banner

    private var turnBanner: some View {
        let myTurn = controller.isMyTurn && !controller.awaitingResult
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                StencilText(myTurn ? "Your Turn" : "Enemy Turn", size: 22, color: myTurn ? Theme.brass : Theme.paper)
                Text(myTurn ? "Select a target on the enemy grid" : "\(controller.opponentName) is taking aim...")
                    .font(.typewriter(12))
                    .foregroundStyle(Theme.khaki)
            }
            Spacer()
            if !myTurn {
                RadarPulse()
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(myTurn ? Theme.brass.opacity(0.14) : Theme.deepSea.opacity(0.8))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(myTurn ? Theme.brass.opacity(0.7) : Theme.khaki.opacity(0.25), lineWidth: 1.5)
                }
        }
        .animation(.easeInOut(duration: 0.3), value: myTurn)
        .padding(.top, 6)
    }

    // MARK: Enemy grid

    private var targetGrid: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Enemy Waters", systemImage: "scope")
                    .font(.stencil(12)).kerning(1.2)
                    .foregroundStyle(Theme.khaki)
                Spacer()
                Text("\(controller.shotsHit)/\(controller.shotsFired) hits")
                    .font(.typewriter(12))
                    .foregroundStyle(Theme.khaki.opacity(0.8))
            }
            BoardGridView(
                mark: enemyMark,
                highlight: pendingTarget ?? controller.lastMyShot?.coordinate,
                interactive: true
            ) { c in
                guard controller.canFire(at: c) else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                pendingTarget = c
                controller.fire(at: c)
            }
            .overlay {
                if controller.awaitingResult {
                    Color.clear.contentShape(Rectangle())
                }
            }
        }
    }

    private func enemyMark(_ c: Coordinate) -> CellMark {
        guard let result = controller.enemyShots[c] else { return .water }
        return result.hit ? .hit(sunk: controller.sunkEnemyCells.contains(c)) : .miss
    }

    // MARK: Ticker

    private var eventTicker: some View {
        HStack(spacing: 10) {
            if let event = controller.events.first {
                Image(systemName: icon(for: event.kind))
                    .foregroundStyle(color(for: event.kind))
                Text(event.text)
                    .font(.typewriter(12))
                    .foregroundStyle(Theme.paper)
                    .lineLimit(2)
                    .id(event.id)
                    .transition(.push(from: .bottom))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8).fill(Theme.navy.opacity(0.7))
        }
        .animation(.spring(duration: 0.35), value: controller.events.first)
    }

    private func icon(for kind: BattleEvent.Kind) -> String {
        switch kind {
        case .info: "antenna.radiowaves.left.and.right"
        case .hit: "burst.fill"
        case .miss: "drop.fill"
        case .sunk: "flame.fill"
        case .victory: "star.fill"
        case .defeat: "xmark.octagon.fill"
        }
    }

    private func color(for kind: BattleEvent.Kind) -> Color {
        switch kind {
        case .info: Theme.khaki
        case .hit: Theme.hit
        case .miss: Theme.miss
        case .sunk: Theme.ember
        case .victory: Theme.victory
        case .defeat: Theme.hit
        }
    }

    // MARK: Fleet status

    private var fleetStatus: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { showOwnBoard = true } label: {
                VStack(spacing: 4) {
                    BoardGridView(mark: controller.myBoard.ownMark, highlight: controller.lastEnemyShot,
                                  showLabels: false, interactive: false)
                        .frame(width: 118, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.khaki.opacity(0.4)) }
                    Text("YOUR FLEET")
                        .font(.stencil(10)).kerning(1)
                        .foregroundStyle(Theme.khaki)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                fleetColumn(title: "Ours", ships: Board.fleet.map { kind in
                    let ship = controller.myBoard.ship(of: kind)
                    let hits = ship.map { controller.myBoard.hits(on: $0) } ?? 0
                    return (kind, hits)
                })
                Divider().overlay(Theme.khaki.opacity(0.3))
                fleetColumn(title: "Enemy sunk", ships: Board.fleet.map { kind in
                    (kind, controller.sunkEnemyShips.contains(kind) ? kind.length : 0)
                })
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.deepSea.opacity(0.7))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.khaki.opacity(0.25)) }
        }
    }

    private func fleetColumn(title: String, ships: [(ShipKind, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.stencil(9)).kerning(1)
                .foregroundStyle(Theme.khaki.opacity(0.8))
            ForEach(ships, id: \.0) { kind, hits in
                let sunk = hits >= kind.length
                HStack(spacing: 4) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 9))
                        .frame(width: 12)
                        .foregroundStyle(sunk ? Theme.hit : Theme.khaki)
                    ForEach(0..<kind.length, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(i < hits ? Theme.hit : Theme.hull.opacity(0.8))
                            .frame(width: 9, height: 6)
                    }
                    Spacer(minLength: 0)
                }
                .opacity(sunk ? 0.6 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ownBoardSheet: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                StencilText("Your Fleet", size: 24)
                Text("Enemy has fired \(controller.myBoard.shots.count) shells at your waters")
                    .font(.typewriter(12))
                    .foregroundStyle(Theme.khaki)
                BoardGridView(mark: controller.myBoard.ownMark, highlight: controller.lastEnemyShot, interactive: false)
                    .padding(.horizontal, 16)
                CommandButton(title: "Back to Battle", icon: "scope", style: .secondary) { showOwnBoard = false }
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct RadarPulse: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(Theme.victory.opacity(0.7), lineWidth: 1.5)
                    .scaleEffect(animate ? 1.4 : 0.3)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(i) * 0.6), value: animate)
            }
            Circle().fill(Theme.victory).frame(width: 6, height: 6)
        }
        .onAppear { animate = true }
    }
}
