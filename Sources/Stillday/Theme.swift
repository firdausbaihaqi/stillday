import AppKit
import SwiftUI
import StilldayCore

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var nativeAppearance: NSAppearance? {
        switch self { case .system: nil; case .light: NSAppearance(named: .aqua); case .dark: NSAppearance(named: .darkAqua) }
    }
}

enum Palette {
    static let background = adaptive(light: 0xF5F5F0, dark: 0x202622)
    static let sidebar = adaptive(light: 0xEBEDE6, dark: 0x19201C)
    static let ink = adaptive(light: 0x303B35, dark: 0xE7ECE4)
    static let muted = adaptive(light: 0x657165, dark: 0xACB9AC)
    static let accent = adaptive(light: 0x617856, dark: 0xAFC49A)
    static let line = adaptive(light: 0xD6DBD1, dark: 0x3F4B42)
    static let selection = adaptive(light: 0xF9FAF7, dark: 0x303C32)
    static let errorInk = adaptive(light: 0x944A2E, dark: 0xF1B994)
    static let errorBackground = adaptive(light: 0xFAEBD9, dark: 0x402D25)

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}
