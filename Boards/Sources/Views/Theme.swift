import SwiftUI

enum Theme {
    static let accent = Color(red: 0.42, green: 0.36, blue: 0.95)

    static var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    static var boardBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var columnBackground: Color {
        #if os(macOS)
        Color.primary.opacity(0.04)
        #else
        Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6)
        #endif
    }
}

struct CardStyle: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(highlighted ? Theme.accent : Color.primary.opacity(0.07), lineWidth: highlighted ? 1.5 : 1)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            }
    }
}

extension View {
    func card(highlighted: Bool = false) -> some View { modifier(CardStyle(highlighted: highlighted)) }
}

struct StatusBadge: View {
    let status: TaskStatus
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
            if !compact {
                Text(status.title)
                    .font(.caption.weight(.medium))
            }
        }
        .foregroundStyle(status.tint)
    }
}

struct PriorityIcon: View {
    let priority: TaskPriority

    var body: some View {
        Group {
            switch priority {
            case .none:
                Image(systemName: "minus")
            case .urgent:
                Image(systemName: "exclamationmark.square.fill")
            case .low, .medium, .high:
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < priority.rawValue ? priority.tint : Color.secondary.opacity(0.3))
                            .frame(width: 3, height: 4 + CGFloat(i) * 3)
                    }
                }
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(priority.tint)
        .frame(width: 16, height: 14)
        .help(priority.title)
    }
}

struct LabelChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var color: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .green, .indigo, .red]
        let hash = text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }
}
