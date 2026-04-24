import SwiftUI

enum StreamShelfTheme {

    // MARK: - Colors

    enum Colors {
        static let accent = Color(red: 1.0, green: 0.54, blue: 0.12)
        static let accentSecondary = Color(red: 0.95, green: 0.28, blue: 0.18)
        static let appBackground = Color(red: 0.045, green: 0.043, blue: 0.047)
        static let surface = Color(red: 0.09, green: 0.088, blue: 0.095)
        static let surfaceElevated = Color(red: 0.135, green: 0.13, blue: 0.14)
        static let primaryText = Color(red: 0.965, green: 0.955, blue: 0.94)
        static let secondaryText = Color(red: 0.72, green: 0.70, blue: 0.68)
        static let tertiaryText = Color(red: 0.52, green: 0.50, blue: 0.48)
        static let separator = Color.white.opacity(0.08)
        static let success = Color(red: 0.28, green: 0.74, blue: 0.46)
        static let warning = Color(red: 1.0, green: 0.70, blue: 0.20)
        static let destructive = Color(red: 0.96, green: 0.30, blue: 0.26)

        static var backdropGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.0), location: 0.4),
                    .init(color: appBackground.opacity(0.98), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static var accentGradient: LinearGradient {
            LinearGradient(
                colors: [accent, accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Typography

    enum Typography {
        static let heroTitle = Font.system(size: 28, weight: .bold)
        static let sectionHeader = Font.headline
        static let cardTitle = Font.system(size: 14, weight: .semibold)
        static let cardSubtitle = Font.system(size: 12, weight: .regular)
        static let metaLabel = Font.system(size: 12, weight: .medium)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let posterCornerRadius: CGFloat = 8
        static let cardCornerRadius: CGFloat = 8
        static let posterWidth: CGFloat = 120
        static let posterHeight: CGFloat = 180
        static let shelfPosterWidth: CGFloat = 118
        static let shelfPosterHeight: CGFloat = 177
        static let heroHeight: CGFloat = 300
    }
}

// MARK: - View Modifiers

extension View {
    func streamShelfCardStyle() -> some View {
        self
            .background(StreamShelfTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: StreamShelfTheme.Dimensions.cardCornerRadius)
                    .stroke(StreamShelfTheme.Colors.separator)
            )
    }

    func sectionHeaderStyle() -> some View {
        self
            .font(StreamShelfTheme.Typography.sectionHeader)
            .padding(.horizontal, StreamShelfTheme.Spacing.lg)
    }
}
