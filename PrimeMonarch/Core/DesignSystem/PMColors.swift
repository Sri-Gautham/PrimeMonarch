import SwiftUI

// Warm cream palette — matches the Health App Final mockup design system.
extension Color {

    // MARK: Backgrounds
    static let pmBackgroundPrimary   = Color(red: 0.961, green: 0.918, blue: 0.847)  // #f5ead8
    static let pmBackgroundSecondary = Color(red: 0.910, green: 0.859, blue: 0.780)  // #e8dbc7

    // MARK: Surfaces (cards)
    static let pmSurfacePrimary  = Color(red: 0.922, green: 0.863, blue: 0.773)      // #ebddc5
    static let pmSurfaceElevated = Color(red: 0.878, green: 0.820, blue: 0.729)      // #e0d1ba

    // MARK: Text
    static let pmTextPrimary   = Color(red: 0.125, green: 0.118, blue: 0.114)        // #201e1d
    static let pmTextSecondary = Color(red: 0.416, green: 0.392, blue: 0.349)        // #6a6459
    static let pmTextTertiary  = Color(red: 0.322, green: 0.310, blue: 0.286)        // #524f49

    // MARK: Accent — warm orange / rust
    static let pmAccentPurple       = Color(red: 0.549, green: 0.286, blue: 0.102)   // #8c491a dark orange
    static let pmAccentPurpleBright = Color(red: 0.776, green: 0.443, blue: 0.224)   // #c67139 primary
    static let pmAccentPink         = Color(red: 0.478, green: 0.541, blue: 0.369)   // #7a8a5e olive green

    // MARK: Status
    static let pmStatusSuccess = Color(red: 0.337, green: 0.388, blue: 0.247)        // #56633f olive
    static let pmStatusWarning = Color(red: 0.776, green: 0.443, blue: 0.224)        // orange
    static let pmStatusError   = Color(red: 0.780, green: 0.200, blue: 0.180)        // warm red

    // MARK: Activity metrics
    static let pmRingEnergy    = Color(red: 0.776, green: 0.443, blue: 0.224)        // #c67139 orange
    static let pmRingHydration = Color(red: 0.392, green: 0.361, blue: 0.314)        // #645c50 warm charcoal
    static let pmRingMovement  = Color(red: 0.478, green: 0.541, blue: 0.369)        // #7a8a5e olive

    // MARK: Tag / pill backgrounds
    static let pmPillOrangeBg  = Color(red: 1.000, green: 0.949, blue: 0.922)        // #fff2eb
    static let pmPillGreenBg   = Color(red: 0.941, green: 0.980, blue: 0.882)        // #f0fae1
    static let pmPillNeutralBg = Color(red: 0.976, green: 0.957, blue: 0.929)        // #f9f4ed

    // MARK: Dividers
    static let pmDivider = Color(red: 0.125, green: 0.118, blue: 0.114).opacity(0.16)
}

// MARK: - ShapeStyle forwarding

extension ShapeStyle where Self == Color {
    static var pmBackgroundPrimary: Color   { .pmBackgroundPrimary }
    static var pmBackgroundSecondary: Color { .pmBackgroundSecondary }
    static var pmSurfacePrimary: Color      { .pmSurfacePrimary }
    static var pmSurfaceElevated: Color     { .pmSurfaceElevated }
    static var pmTextPrimary: Color         { .pmTextPrimary }
    static var pmTextSecondary: Color       { .pmTextSecondary }
    static var pmTextTertiary: Color        { .pmTextTertiary }
    static var pmAccentPurple: Color        { .pmAccentPurple }
    static var pmAccentPurpleBright: Color  { .pmAccentPurpleBright }
    static var pmAccentPink: Color          { .pmAccentPink }
    static var pmStatusSuccess: Color       { .pmStatusSuccess }
    static var pmStatusWarning: Color       { .pmStatusWarning }
    static var pmStatusError: Color         { .pmStatusError }
    static var pmRingEnergy: Color          { .pmRingEnergy }
    static var pmRingHydration: Color       { .pmRingHydration }
    static var pmRingMovement: Color        { .pmRingMovement }
    static var pmDivider: Color             { .pmDivider }
}

// MARK: - Gradients

@MainActor
extension LinearGradient {
    static var pmPurpleGradient: LinearGradient {
        LinearGradient(
            colors: [.pmAccentPurpleBright, .pmAccentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var pmHeroGradient: LinearGradient {
        LinearGradient(
            colors: [Color.pmSurfacePrimary, Color.pmBackgroundPrimary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
