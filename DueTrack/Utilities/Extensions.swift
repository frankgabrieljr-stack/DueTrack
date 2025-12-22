import Foundation
import SwiftUI

// MARK: - Color Extensions
extension Color {
    /// Brand accent that adapts per appearance:
    /// - Light mode: deep navy
    /// - Dark mode: light sky blue for better contrast and softer feel
    static let primaryBlue = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            // Light sky blue
            return UIColor(red: 0.30, green: 0.78, blue: 0.98, alpha: 1.0) // ~#4CCBFA
        } else {
            // Original deep navy
            return UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1.0) // ~#1E3A8A
        }
    })
    static let accentGreen = Color(hex: "#10B981")
    static let backgroundGray = Color(hex: "#F3F4F6")
    static let overdueRed = Color(hex: "#EF4444")
    static let upcomingYellow = Color(hex: "#F59E0B")
    static let futureGray = Color(hex: "#6B7280")
    
    // Dark mode adaptive colors
    static let cardBackground = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            // Softer, higher-contrast card background for dark mode
            return UIColor(red: 0.15, green: 0.17, blue: 0.20, alpha: 1.0)
        } else {
            return UIColor.white
        }
    })
    
    static let adaptiveBackground = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            // Avoid pure black; use a deep charcoal that’s easier on the eyes
            return UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
        } else {
            return UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0) // #F3F4F6
        }
    })
    
    static let adaptiveText = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            // Slightly off‑white to reduce glare on dark backgrounds
            return UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        } else {
            return UIColor.label
        }
    })
    
    static let adaptiveSecondaryText = Color(uiColor: UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            // Lighten secondary text in dark mode for better readability
            return UIColor(white: 0.8, alpha: 1.0)
        } else {
            return UIColor.secondaryLabel
        }
    })
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Double Extensions
extension Double {
    func currencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}

// MARK: - Date Extensions
extension Date {
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func startOfMonth() -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
    
    func endOfMonth() -> Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth()) ?? self
    }
}

