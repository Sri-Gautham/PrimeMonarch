import SwiftUI

// MARK: - Keyboard type helpers (UIKit-conditional)

extension View {
    /// Apply number pad keyboard on iOS; no-op on other platforms.
    func pmNumberPad() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    /// Apply decimal pad keyboard on iOS; no-op on other platforms.
    func pmDecimalPad() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
