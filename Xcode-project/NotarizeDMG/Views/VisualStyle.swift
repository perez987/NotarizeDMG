import SwiftUI

enum AppTheme {
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.27, green: 0.56, blue: 1.0),
            Color(red: 0.54, green: 0.44, blue: 0.98),
            Color(red: 0.95, green: 0.47, blue: 0.76),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func windowGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.10, green: 0.11, blue: 0.14),
                    Color(red: 0.13, green: 0.14, blue: 0.19),
                    Color(red: 0.09, green: 0.11, blue: 0.15),
                ]
                : [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.95, green: 0.93, blue: 1.0),
                    Color(red: 0.90, green: 0.97, blue: 0.98),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func surfaceGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.21, green: 0.22, blue: 0.27).opacity(0.88),
                    Color(red: 0.13, green: 0.14, blue: 0.19).opacity(0.78),
                ]
                : [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.16),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func borderGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.24),
                    Color.white.opacity(0.10),
                ]
                : [
                    Color.white.opacity(0.85),
                    Color.white.opacity(0.22),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func accentGlow(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.27, green: 0.56, blue: 1.0).opacity(0.12),
                    Color(red: 0.54, green: 0.44, blue: 0.98).opacity(0.09),
                    Color(red: 0.95, green: 0.47, blue: 0.76).opacity(0.06),
                ]
                : [
                    Color(red: 0.27, green: 0.56, blue: 1.0).opacity(0.30),
                    Color(red: 0.54, green: 0.44, blue: 0.98).opacity(0.22),
                    Color(red: 0.95, green: 0.47, blue: 0.76).opacity(0.18),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.52) : Color.black.opacity(0.12)
    }

    static func cardMaterial(for colorScheme: ColorScheme) -> Material {
        colorScheme == .dark ? .regularMaterial : .ultraThinMaterial
    }

    static func surfaceHighlight(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.03),
                ]
                : [
                    Color.white.opacity(0.24),
                    Color.white.opacity(0.05),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func raisedSurfaceFill(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return emphasized
                ? Color(red: 0.26, green: 0.28, blue: 0.34).opacity(0.90)
                : Color(red: 0.18, green: 0.19, blue: 0.24).opacity(0.82)
        }
        return emphasized ? Color.white.opacity(0.34) : Color.white.opacity(0.20)
    }

    static func fieldFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.16, blue: 0.20).opacity(0.94)
            : Color.white.opacity(0.34)
    }

    static func secondaryProminentTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.27, green: 0.29, blue: 0.34)
            : Color.white.opacity(0.24)
    }

    static func warningFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.orange.opacity(0.18) : Color.white.opacity(0.35)
    }

    static func logBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.09, green: 0.10, blue: 0.13).opacity(0.92)
            : Color.white.opacity(0.12)
    }

    static func scrim(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.42) : Color.black.opacity(0.18)
    }
}

extension View {
    func glassCard(
        colorScheme: ColorScheme,
        cornerRadius: CGFloat = 24,
        accentOpacity: Double = 0.22
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.cardMaterial(for: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.surfaceGradient(for: colorScheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.surfaceHighlight(for: colorScheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppTheme.accentGlow(for: colorScheme))
                        .opacity(colorScheme == .dark ? accentOpacity * 0.55 : accentOpacity)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppTheme.borderGradient(for: colorScheme), lineWidth: 1)
                }
                .shadow(color: AppTheme.shadowColor(for: colorScheme), radius: 18, x: 0, y: 12)
        }
    }
}
