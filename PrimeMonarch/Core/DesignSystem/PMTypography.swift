import SwiftUI

// Text style helpers. All use SF Pro with Dynamic Type support.
extension Font {
    static let pmLargeTitle    = Font.system(.largeTitle,  design: .default, weight: .bold)
    static let pmScreenTitle   = Font.system(.title,       design: .default, weight: .bold)
    static let pmSectionTitle  = Font.system(.title2,      design: .default, weight: .semibold)
    static let pmCardTitle     = Font.system(.headline,    design: .default, weight: .semibold)
    static let pmBody          = Font.system(.body,        design: .default, weight: .regular)
    static let pmBodyMedium    = Font.system(.body,        design: .default, weight: .medium)
    static let pmSecondaryBody = Font.system(.subheadline, design: .default, weight: .regular)
    static let pmMetricValue   = Font.system(.title,       design: .rounded, weight: .bold)
    static let pmMetricLarge   = Font.system(.largeTitle,  design: .rounded, weight: .bold)
    static let pmCaption       = Font.system(.caption,     design: .default, weight: .regular)
    static let pmCaptionMedium = Font.system(.caption,     design: .default, weight: .medium)
    static let pmButtonLabel   = Font.system(.body,        design: .default, weight: .semibold)
    static let pmRankLabel     = Font.system(.caption,     design: .default, weight: .bold)
    // Small uppercase label — callers should add .tracking(0.6) for full kicker effect.
    static let pmKicker        = Font.system(size: 11,     weight: .semibold, design: .default)
}

// MARK: - View Modifier Helpers

struct PMTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }
}

extension View {
    func pmTextStyle(_ font: Font, color: Color = .pmTextPrimary) -> some View {
        modifier(PMTextStyle(font: font, color: color))
    }
}
