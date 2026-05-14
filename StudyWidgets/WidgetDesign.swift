// WidgetDesign — minimal token mirror so widgets can use the same palette
// without importing the main app target.

import SwiftUI

enum WT {
    enum Color {
        static let primary    = SwiftUI.Color(red: 0x3D / 255, green: 0x7B / 255, blue: 0xFF / 255)
        static let surface    = SwiftUI.Color(red: 0xF5 / 255, green: 0xF7 / 255, blue: 0xFB / 255)
        static let textPrimary   = SwiftUI.Color(red: 0x1A / 255, green: 0x1D / 255, blue: 0x29 / 255)
        static let textSecondary = SwiftUI.Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
    }
}

extension SwiftUI.Color {
    static func fromHexString(_ hex: String) -> SwiftUI.Color {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return WT.Color.primary }
        return SwiftUI.Color(
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0
        )
    }
}
