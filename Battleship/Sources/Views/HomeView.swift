import GameKit
import SwiftUI

struct HomeView: View {
    @State private var gameCenter = GameCenterSession()
    @State private var controller: MatchController?
    @State private var nearby: NearbyTransport?
    @State private var showMatchmaker = false
    @State private var showNearbyLobby = false
    @AppStorage("callsign") private var callsign = ""

    private var playerName: String {
        if !callsign.trimmingCharacters(in: .whitespaces).isEmpty { return callsign }
        return gameCenter.isAuthenticated ? gameCenter.alias : UIDevice.current.name
    }

    var body: some View {
        ZStack {
            OceanBackdrop()
            if let controller {
                MatchView(controller: controller) {
                    withAnimation(.easeInOut(duration: 0.4)) { self.controller = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                menu
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { gameCenter.authenticate() }
        .sheet(isPresented: $showMatchmaker) {
            GameCenterMatchmakerView(
                onMatch: { match in
                    showMatchmaker = false
                    startMatch(GameCenterTransport(match: match))
                },
                onCancel: { showMatchmaker = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNearbyLobby, onDismiss: {
            if controller == nil { nearby?.disconnect() }
            nearby = nil
        }) {
            if let nearby {
                NearbyLobbyView(transport: nearby) {
                    showNearbyLobby = false
                    startMatch(nearby)
                }
            }
        }
    }

    private var menu: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            emblem
            Spacer(minLength: 24)

            VStack(spacing: 12) {
                modeCard(
                    title: "Online Battle",
                    subtitle: gameCenterSubtitle,
                    icon: "globe.americas.fill",
                    enabled: gameCenter.isAuthenticated
                ) { showMatchmaker = true }

                modeCard(
                    title: "Nearby Battle",
                    subtitle: "Two iPhones on the same Wi-Fi or Bluetooth",
                    icon: "wifi"
                ) {
                    let transport = NearbyTransport(displayName: playerName)
                    nearby = transport
                    transport.start()
                    showNearbyLobby = true
                }

                modeCard(
                    title: "Practice",
                    subtitle: "Train against Admiral Yamamoto (AI)",
                    icon: "cpu"
                ) { startMatch(PracticeTransport()) }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 20)
            callsignField
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            Text("PACIFIC THEATRE · 1942")
                .font(.typewriter(10))
                .foregroundStyle(Theme.khaki.opacity(0.5))
                .padding(.bottom, 8)
        }
    }

    private var gameCenterSubtitle: String {
        switch gameCenter.state {
        case .unknown, .authenticating: "Connecting to Game Center..."
        case let .authenticated(alias): "Matchmaking via Game Center as \(alias)"
        case .unavailable: "Sign in to Game Center in Settings to play online"
        }
    }

    private var emblem: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.brass.opacity(0.6), lineWidth: 3)
                    .frame(width: 128, height: 128)
                Circle()
                    .strokeBorder(Theme.brass.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .frame(width: 110, height: 110)
                Image(systemName: "ferry.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
                ForEach(0..<8, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(Theme.brass)
                        .offset(y: -64)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
            StencilText("Battleship", size: 40, color: Theme.paper)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
            Text("NAVAL COMBAT · TWO PLAYER")
                .font(.typewriter(11, weight: .bold))
                .kerning(2)
                .foregroundStyle(Theme.brass)
        }
    }

    private func modeCard(title: String, subtitle: String, icon: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brass)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.navy.opacity(0.7)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.stencil(16)).kerning(1.5)
                        .foregroundStyle(Theme.paper)
                    Text(subtitle)
                        .font(.typewriter(11))
                        .foregroundStyle(Theme.khaki.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.khaki.opacity(0.6))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.deepSea.opacity(0.85))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.khaki.opacity(0.3), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }

    private var callsignField: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.text.rectangle")
                .foregroundStyle(Theme.khaki)
            TextField("Callsign", text: $callsign, prompt: Text("Callsign (shown to your opponent)").foregroundStyle(Theme.khaki.opacity(0.5)))
                .font(.typewriter(13))
                .foregroundStyle(Theme.paper)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10).fill(Theme.navy.opacity(0.6))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.khaki.opacity(0.25)) }
        }
    }

    private func startMatch(_ transport: GameTransport) {
        let controller = MatchController(transport: transport, playerName: playerName)
        withAnimation(.easeInOut(duration: 0.45)) { self.controller = controller }
    }
}

struct NearbyLobbyView: View {
    let transport: NearbyTransport
    let onConnected: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    RadarPulse().frame(width: 140, height: 140).scaleEffect(2.2)
                    Image(systemName: "wifi")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.paper)
                }
                .frame(height: 180)
                StencilText(title, size: 26)
                Text(detail)
                    .font(.typewriter(13))
                    .foregroundStyle(Theme.khaki)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if !transport.discoveredPeers.isEmpty {
                    RivetedPanel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SHIPS ON RADAR").font(.stencil(11)).kerning(1).foregroundStyle(Theme.khaki)
                            ForEach(transport.discoveredPeers, id: \.self) { name in
                                Label(name, systemImage: "ferry.fill")
                                    .font(.typewriter(13))
                                    .foregroundStyle(Theme.paper)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 32)
                }
                Spacer()
                CommandButton(title: "Cancel", style: .secondary) { dismiss() }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: transport.isConnected) { _, connected in
            if connected {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    onConnected()
                }
            }
        }
    }

    private var title: String {
        switch transport.state {
        case .searching: "Scanning"
        case .connecting: "Hailing"
        case .connected: "Contact"
        case .failed: "No Signal"
        }
    }

    private var detail: String {
        switch transport.state {
        case .searching: "Open Battleship on the other iPhone and choose Nearby Battle. Both devices must be on the same Wi-Fi or have Bluetooth on."
        case let .connecting(name): "Establishing a secure line with \(name)..."
        case let .connected(name): "Connected to \(name). Preparing the battle..."
        case let .failed(reason): reason
        }
    }
}
