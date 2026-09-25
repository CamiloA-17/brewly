import SwiftUI
import UIKit

/// Brewly's coffee-inspired palette. Every color adapts to light and dark mode.
public extension Color {
    /// Main brand color (roasted coffee / crema in dark mode).
    static let brewlyAccent = Color(light: 0xB06F3A, dark: 0xD89E66)
    /// Deep espresso for strong text and icons.
    static let brewlyEspresso = Color(light: 0x3B241A, dark: 0xF3E6DA)
    /// Warm background for cards.
    static let brewlyCard = Color(light: 0xF8F1EA, dark: 0x2A211C)
    /// Secondary tint for badges.
    static let brewlyCrema = Color(light: 0xEAD7C3, dark: 0x4A382D)
    /// Validation and error messages, readable on light and dark backgrounds.
    static let brewlyError = Color(light: 0xB3261E, dark: 0xF2B8B5)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Spacing scale used across the app.
public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
}
