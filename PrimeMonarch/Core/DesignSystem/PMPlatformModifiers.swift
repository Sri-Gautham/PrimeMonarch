import SwiftUI

// Wrappers around iOS-only navigation modifiers.
// On macOS/visionOS the navigation bar behaves differently, so these are no-ops there.

extension View {
    /// Sets large navigation title style with dark toolbar on iOS; no-op elsewhere.
    func pmLargeNavTitle() -> some View {
        #if os(iOS)
        self
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Hides the navigation bar on iOS; no-op elsewhere.
    func pmHideNavBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Applies numeric or default keyboard type on iOS; no-op on other platforms.
    func pmKeyboardType(isNumeric: Bool) -> some View {
        #if os(iOS)
        self.keyboardType(isNumeric ? .decimalPad : .default)
        #else
        self
        #endif
    }
}
