import SwiftUI

struct GameOverView: View {
    let controller: MatchController
    let victory: Bool
    let onExit: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: victory ? "medal.fill" : "xmark.octagon.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(victory ? Theme.brass : Theme.hit)
                .shadow(color: (victory ? Theme.brass : Theme.hit).opacity(0.6), radius: 20)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                StencilText(victory ? "Victory" : "Defeat", size: 44, color: victory ? Theme.brass : Theme.paper)
                Text(victory
                     ? "The enemy fleet lies at the bottom of the sea."
                     : "\(controller.opponentName) has sunk your fleet.")
                    .font(.typewriter(13))
                    .foregroundStyle(Theme.khaki)
                    .multilineTextAlignment(.center)
            }
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)

            RivetedPanel {
                HStack {
                    stat("Shots", "\(controller.shotsFired)")
                    Divider().frame(height: 40).overlay(Theme.khaki.opacity(0.3))
                    stat("Hits", "\(controller.shotsHit)")
                    Divider().frame(height: 40).overlay(Theme.khaki.opacity(0.3))
                    stat("Accuracy", "\(Int(controller.accuracy * 100))%")
                    Divider().frame(height: 40).overlay(Theme.khaki.opacity(0.3))
                    stat("Sunk", "\(controller.sunkEnemyShips.count)/\(Board.fleet.count)")
                }
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)

            BoardGridView(mark: controller.myBoard.ownMark, showLabels: false, interactive: false)
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.khaki.opacity(0.4)) }
                .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 10) {
                if controller.transport.kind != .practice {
                    if controller.rematchRequested {
                        HStack(spacing: 10) {
                            ProgressView().tint(Theme.brass)
                            Text("WAITING FOR \(controller.opponentName.uppercased())")
                                .font(.stencil(13)).kerning(1.2)
                                .foregroundStyle(Theme.brass)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    } else {
                        CommandButton(title: controller.opponentWantsRematch ? "Accept Rematch" : "Rematch",
                                      icon: "arrow.counterclockwise") {
                            controller.requestRematch()
                        }
                    }
                } else {
                    CommandButton(title: "Play Again", icon: "arrow.counterclockwise") {
                        controller.requestRematch()
                    }
                }
                CommandButton(title: "Return to Port", icon: "house.fill", style: .secondary, action: onExit)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) { appeared = true }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.stencil(22))
                .foregroundStyle(Theme.paper)
            Text(label.uppercased())
                .font(.typewriter(10))
                .foregroundStyle(Theme.khaki.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}
