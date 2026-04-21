import SwiftUI

enum Theme {
    static let bg        = Color(hex: "#0d0d14")
    static let bg2       = Color(hex: "#13131d")
    static let bg3       = Color(hex: "#1a1a28")
    static let accent    = Color(hex: "#ff3c3c")
    static let accent2   = Color(hex: "#ff6b35")
    static let text      = Color(hex: "#f0f0f5")
    static let text2     = Color(hex: "#8888a0")
    static let text3     = Color(hex: "#555568")
    static let green     = Color(hex: "#4caf92")
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.bg2)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}
