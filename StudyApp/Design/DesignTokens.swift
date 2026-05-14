// DesignTokens — colors, spacing, radius, shadow.
// Numbers match PLAN.md §3.

import SwiftUI

enum DT {
    enum Color {
        static let primary       = SwiftUI.Color(hex: 0x3D7BFF)
        static let primaryDark   = SwiftUI.Color(hex: 0x2E5DC8)
        static let background    = SwiftUI.Color(hex: 0xFFFFFF)
        static let backgroundDark = SwiftUI.Color(hex: 0x0A0E1A)
        static let surface       = SwiftUI.Color(hex: 0xF5F7FB)
        static let surfaceDark   = SwiftUI.Color(hex: 0x131826)
        static let textPrimary   = SwiftUI.Color(hex: 0x1A1D29)
        static let textSecondary = SwiftUI.Color(hex: 0x6B7280)
        static let success       = SwiftUI.Color(hex: 0x4CAF50)
        static let warning       = SwiftUI.Color(hex: 0xFFB020)
        static let error         = SwiftUI.Color(hex: 0xFF4757)

        static let subjectPalette: [SwiftUI.Color] = [
            .init(hex: 0xFF6B6B), .init(hex: 0xFFA94D), .init(hex: 0xFFD43B),
            .init(hex: 0x69DB7C), .init(hex: 0x4DABF7), .init(hex: 0x748FFC),
            .init(hex: 0xB197FC), .init(hex: 0xF783AC), .init(hex: 0x868E96),
            .init(hex: 0x20C997),
        ]
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let card: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Typography {
        static let title1   = Font.system(size: 28, weight: .bold)
        static let title2   = Font.system(size: 22, weight: .bold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body     = Font.system(size: 15, weight: .regular)
        static let caption  = Font.system(size: 12, weight: .medium)
    }
}

extension SwiftUI.Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Parses hex strings like "#3D7BFF" or "3D7BFF".
    init?(hexString: String) {
        var s = hexString
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
