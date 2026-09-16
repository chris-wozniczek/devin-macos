import SwiftUI

enum Theme {
    static let navy = Color(red: 0.04, green: 0.09, blue: 0.15)
    static let deepSea = Color(red: 0.07, green: 0.18, blue: 0.28)
    static let sea = Color(red: 0.10, green: 0.27, blue: 0.40)
    static let steel = Color(red: 0.36, green: 0.42, blue: 0.48)
    static let hull = Color(red: 0.55, green: 0.58, blue: 0.60)
    static let khaki = Color(red: 0.79, green: 0.70, blue: 0.49)
    static let brass = Color(red: 0.87, green: 0.68, blue: 0.29)
    static let paper = Color(red: 0.93, green: 0.89, blue: 0.80)
    static let hit = Color(red: 0.87, green: 0.28, blue: 0.20)
    static let ember = Color(red: 1.0, green: 0.56, blue: 0.20)
    static let miss = Color(red: 0.62, green: 0.78, blue: 0.88)
    static let victory = Color(red: 0.35, green: 0.72, blue: 0.45)

    static let background = LinearGradient(
        colors: [navy, deepSea, navy],
        startPoint: .top, endPoint: .bottom
    )
}

extension Font {
    static func stencil(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func typewriter(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Uppercase, wide-tracked heading used across the game.
struct StencilText: View {
    let text: String
    var size: CGFloat = 28
    var color: Color = Theme.paper

    init(_ text: String, size: CGFloat = 28, color: Color = Theme.paper) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.stencil(size))
            .kerning(size * 0.12)
            .foregroundStyle(color)
    }
}

struct RivetedPanel<Content: View>: View {
    var tint: Color = Theme.deepSea
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.85))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.khaki.opacity(0.35), lineWidth: 1.5)
                    }
                    .overlay(alignment: .topLeading) { rivets }
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
            }
    }

    private var rivets: some View {
        GeometryReader { geo in
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Theme.khaki.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .position(
                        x: i % 2 == 0 ? 9 : geo.size.width - 9,
                        y: i < 2 ? 9 : geo.size.height - 9
                    )
            }
        }
    }
}

struct CommandButton: View {
    enum Style { case primary, secondary, danger }

    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }
                Text(title.uppercased())
                    .font(.stencil(15))
                    .kerning(1.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(border, lineWidth: 1.5)
                    }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var foreground: Color {
        switch style {
        case .primary: Theme.navy
        case .secondary: Theme.paper
        case .danger: Theme.paper
        }
    }

    private var background: Color {
        switch style {
        case .primary: Theme.brass
        case .secondary: Theme.sea.opacity(0.6)
        case .danger: Theme.hit.opacity(0.8)
        }
    }

    private var border: Color {
        switch style {
        case .primary: Theme.khaki
        case .secondary: Theme.khaki.opacity(0.5)
        case .danger: Theme.ember.opacity(0.7)
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Subtle animated wave lines used as a backdrop.
struct OceanBackdrop: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                Canvas { ctx, size in
                    let t = context.date.timeIntervalSinceReferenceDate
                    for i in 0..<7 {
                        var path = Path()
                        let y = size.height * (0.25 + CGFloat(i) * 0.1)
                        path.move(to: CGPoint(x: 0, y: y))
                        var x: CGFloat = 0
                        while x <= size.width {
                            let dy = sin((x / 60) + CGFloat(t) * 0.8 + CGFloat(i)) * 5
                            path.addLine(to: CGPoint(x: x, y: y + dy))
                            x += 6
                        }
                        ctx.stroke(path, with: .color(Theme.miss.opacity(0.07)), lineWidth: 1.5)
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
