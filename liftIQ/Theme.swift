import SwiftUI

// Design tokens from README.md — dark-first.
enum Theme {
    static let background = Color(hex: 0x050507)
    static let card = Color(hex: 0x101014)
    static let accent = Color(hex: 0x0A84FF)
    static let success = Color(hex: 0x30D158)
    static let warmup = Color(hex: 0xFF9F0A)
    static let gold = Color(hex: 0xFFD60A)
    static let destructive = Color(hex: 0xFF453A)

    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.38)
    static let hairline = Color.white.opacity(0.09)
    static let separator = Color.white.opacity(0.08)
    static let insetControl = Color.white.opacity(0.07)
    static let completedRowTint = Color(hex: 0x30D158).opacity(0.07)
    static let currentRowTint = Color(hex: 0x0A84FF).opacity(0.08)
    static let gridline = Color.white.opacity(0.06)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// Mono data label — stats, timers, dates, eyebrows.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// `★ FAVORITES`-style section eyebrow.
struct EyebrowText: View {
    let text: String
    var color: Color = .white.opacity(0.4)
    var body: some View {
        Text(text.uppercased())
            .font(.mono(11, .semibold))
            .kerning(1)
            .foregroundStyle(color)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var borderColor: Color = Theme.hairline
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16, border: Color = Theme.hairline) -> some View {
        modifier(CardModifier(padding: padding, borderColor: border))
    }
}

/// "lift" white + "IQ" blue wordmark.
struct Wordmark: View {
    var body: some View {
        Text("lift\(Text("IQ").foregroundStyle(Theme.accent))")
            .foregroundStyle(.white)
            .font(.system(size: 34, weight: .bold))
    }
}
