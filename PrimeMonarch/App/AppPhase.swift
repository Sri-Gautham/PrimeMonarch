import Foundation

enum AppPhase: Equatable {
    case launching
    case welcome
    case authentication
    case onboarding
    case locked         // biometric lock screen shown on launch or foreground resume
    case main
    case storageFailure(String)

    static func == (lhs: AppPhase, rhs: AppPhase) -> Bool {
        switch (lhs, rhs) {
        case (.launching, .launching), (.welcome, .welcome),
             (.authentication, .authentication), (.onboarding, .onboarding),
             (.locked, .locked), (.main, .main):
            return true
        case (.storageFailure(let a), .storageFailure(let b)):
            return a == b
        default:
            return false
        }
    }
}
