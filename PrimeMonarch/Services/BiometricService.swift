import Foundation
import LocalAuthentication

// MARK: - Types

enum BiometricType {
    case faceID, touchID, none
}

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notAvailable:         return "Biometric authentication is not available on this device."
        case .authenticationFailed: return "Authentication failed. Please try again."
        case .userCancelled:        return nil
        }
    }
}

// MARK: - Service

enum BiometricService {

    static var biometricType: BiometricType {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        switch ctx.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        default:       return .none
        }
    }

    static var isAvailable: Bool { biometricType != .none }

    /// Presents the system biometric prompt. Throws `BiometricError.userCancelled` when dismissed.
    static func authenticate(reason: String) async throws {
        let ctx = LAContext()
        var policyError: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            throw BiometricError.notAvailable
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if success {
                    continuation.resume()
                } else if let laErr = error as? LAError, laErr.code == .userCancel {
                    continuation.resume(throwing: BiometricError.userCancelled)
                } else {
                    continuation.resume(throwing: BiometricError.authenticationFailed)
                }
            }
        }
    }
}
