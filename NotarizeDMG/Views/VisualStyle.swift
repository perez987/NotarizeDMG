import SwiftUI

enum AppTheme {
    static let windowGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.95, green: 0.93, blue: 1.0),
            Color(red: 0.90, green: 0.97, blue: 0.98),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surfaceGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.55),
            Color.white.opacity(0.16),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let borderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.85),
            Color.white.opacity(0.22),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.27, green: 0.56, blue: 1.0),
            Color(red: 0.54, green: 0.44, blue: 0.98),
            Color(red: 0.95, green: 0.47, blue: 0.76),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGlow = LinearGradient(
        colors: [
            Color(red: 0.27, green: 0.56, blue: 1.0).opacity(0.30),
            Color(red: 0.54, green: 0.44, blue: 0.98).opacity(0.22),
            Color(red: 0.95, green: 0.47, blue: 0.76).opacity(0.18),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let shadowColor = Color.black.opacity(0.12)
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, accentOpacity: Double = 0.22) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.surfaceGradient)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.accentGlow)
                        .opacity(accentOpacity)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
                }
                .shadow(color: AppTheme.shadowColor, radius: 18, x: 0, y: 12)
        }
    }
}
