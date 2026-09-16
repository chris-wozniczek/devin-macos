import SwiftUI

/// Hosts a single match and swaps between placement, battle and result screens.
struct MatchView: View {
    let controller: MatchController
    let onExit: () -> Void
    @State private var confirmLeave = false

    var body: some View {
        ZStack {
            OceanBackdrop()
            VStack(spacing: 0) {
                topBar
                Group {
                    switch controller.phase {
                    case .placement, .awaitingOpponent:
                        PlacementView(controller: controller)
                            .id(controller.round)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    case .battle:
                        BattleView(controller: controller)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    case let .finished(victory):
                        GameOverView(controller: controller, victory: victory, onExit: exit)
                            .transition(.opacity)
                    case .opponentLeft:
                        opponentLeft
                            .transition(.opacity)
                    }
                }
                .animation(.spring(duration: 0.5), value: controller.phase)
            }
        }
        .confirmationDialog("Abandon the battle?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Abandon Ship", role: .destructive, action: exit)
            Button("Keep Fighting", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if case .finished = controller.phase { exit() } else if controller.phase == .opponentLeft { exit() } else { confirmLeave = true }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.khaki)
                    .padding(10)
                    .background(Circle().fill(Theme.deepSea.opacity(0.8)))
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: transportIcon)
                    .font(.system(size: 11, weight: .bold))
                Text("VS \(controller.opponentName.uppercased())")
                    .font(.stencil(11)).kerning(1.2)
            }
            .foregroundStyle(Theme.khaki)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.deepSea.opacity(0.8)))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var transportIcon: String {
        switch controller.transport.kind {
        case .gameCenter: "globe"
        case .nearby: "wifi"
        case .practice: "cpu"
        }
    }

    private var opponentLeft: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundStyle(Theme.khaki)
            StencilText("Signal Lost", size: 32)
            Text("\(controller.opponentName) has left the battle.")
                .font(.typewriter(13))
                .foregroundStyle(Theme.khaki)
            Spacer()
            CommandButton(title: "Return to Port", icon: "house.fill", action: exit)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private func exit() {
        controller.leave()
        onExit()
    }
}
