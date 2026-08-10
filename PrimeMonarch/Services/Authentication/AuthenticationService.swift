import AuthenticationServices
import Foundation
// Supabase SPM: https://github.com/supabase/supabase-swift  (2.x.x)
import Supabase
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Models

struct AuthSession {
    var isAuthenticated: Bool = false
    var isGuest: Bool = false
    var appleUserIdentifier: String? = nil
    var supabaseUserId: String? = nil   // Supabase auth user UUID
    var displayName: String? = nil
    var email: String? = nil
}

enum AuthError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign in was cancelled."
        case .failed(let reason): return "Sign in failed: \(reason)"
        }
    }
}

// MARK: - Protocol

@MainActor
protocol AuthenticationServiceProtocol: AnyObject {
    var session: AuthSession { get }
    func checkExistingSession() async
    func continueAsGuest() async
    func signInWithApple() async throws
    /// Returns `true` if email confirmation is required before the account is active.
    func signUpWithEmail(email: String, password: String) async throws -> Bool
    func signInWithEmail(email: String, password: String) async throws
    func signOut() async
    /// Converts a guest session to a full Apple-linked account. Local data is preserved.
    func upgradeGuestWithApple() async throws
    /// Converts a guest session to a full email account. Returns `true` if confirmation email was sent.
    func upgradeGuestWithEmail(email: String, password: String) async throws -> Bool
}

// MARK: - Implementation

@Observable @MainActor
final class AuthenticationService: NSObject, AuthenticationServiceProtocol {

    private(set) var session = AuthSession()
    private var signInContinuation: CheckedContinuation<Void, Error>?

    // MARK: Session lifecycle

    func checkExistingSession() async {
        // Supabase persists its session in Keychain and auto-refreshes tokens.
        // Checking currentSession is the primary path for returning users.
        if let currentSession = SupabaseClient.shared.auth.currentSession {
            session.supabaseUserId = currentSession.user.id.uuidString
            session.isAuthenticated = true
            // Anonymous users have no email or phone
            session.isGuest = currentSession.user.email == nil
                           && currentSession.user.phone == nil
            session.appleUserIdentifier = UserDefaults.standard.string(forKey: Keys.appleUserID)
            session.displayName         = UserDefaults.standard.string(forKey: Keys.displayName)
            return
        }

        // Fallback: Supabase session absent (first launch offline, or session expired).
        // Try Apple credential state to avoid forcing re-auth on connectivity loss.
        if let userID = UserDefaults.standard.string(forKey: Keys.appleUserID) {
            let provider = ASAuthorizationAppleIDProvider()
            let state = try? await provider.credentialState(forUserID: userID)
            if state == .authorized {
                session.isAuthenticated     = true
                session.appleUserIdentifier = userID
                session.displayName         = UserDefaults.standard.string(forKey: Keys.displayName)
                return
            }
            UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
        }

        if UserDefaults.standard.bool(forKey: Keys.isGuest) {
            session.isAuthenticated = true
            session.isGuest = true
        }
    }

    func continueAsGuest() async {
        do {
            // Anonymous sign-in creates a real Supabase user UUID.
            // This UUID becomes the Row Level Security key for all user data.
            // If the user later signs in with Apple, call supabase.auth.linkIdentity()
            // to merge the anonymous account with the Apple identity.
            let guestSession = try await SupabaseClient.shared.auth.signInAnonymously()
            session.supabaseUserId = guestSession.user.id.uuidString
        } catch {
            // Offline or Supabase unavailable — allow local-only guest session.
            print("[Auth] Anonymous sign-in unavailable: \(error.localizedDescription)")
        }
        UserDefaults.standard.set(true, forKey: Keys.isGuest)
        session.isGuest = true
        session.isAuthenticated = true
    }

    func signInWithApple() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            #if canImport(UIKit)
            controller.presentationContextProvider = self
            #endif
            controller.performRequests()
        }
    }

    func signUpWithEmail(email: String, password: String) async throws -> Bool {
        let response = try await SupabaseClient.shared.auth.signUp(email: email, password: password)
        if let supabaseSession = response.session {
            // Email auto-confirmed (common in dev or if confirmation is disabled in Supabase)
            session.supabaseUserId = supabaseSession.user.id.uuidString
            session.email = supabaseSession.user.email
            session.isAuthenticated = true
            session.isGuest = false
            return false
        } else {
            // Supabase sent a confirmation email — user must verify before signing in
            return true
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        let supabaseSession = try await SupabaseClient.shared.auth.signIn(email: email, password: password)
        session.supabaseUserId = supabaseSession.user.id.uuidString
        session.email = supabaseSession.user.email
        session.isAuthenticated = true
        session.isGuest = false
    }

    func signOut() async {
        try? await SupabaseClient.shared.auth.signOut()
        UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
        UserDefaults.standard.removeObject(forKey: Keys.isGuest)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
        session = AuthSession()
    }

    func upgradeGuestWithApple() async throws {
        try await signInWithApple()
        clearGuestState()
    }

    func upgradeGuestWithEmail(email: String, password: String) async throws -> Bool {
        let needsConfirmation = try await signUpWithEmail(email: email, password: password)
        if !needsConfirmation { clearGuestState() }
        return needsConfirmation
    }

    // MARK: Storage keys

    private func clearGuestState() {
        session.isGuest = false
        UserDefaults.standard.removeObject(forKey: Keys.isGuest)
    }

    private enum Keys {
        // SECURITY: appleUserID should be migrated to Keychain before shipping
        static let appleUserID = "pm_apple_user_id"
        static let isGuest     = "pm_is_guest"
        static let displayName = "pm_display_name"
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.signInContinuation?.resume(throwing: AuthError.failed("Invalid credential type"))
                self.signInContinuation = nil
            }
            return
        }

        let userID = credential.user
        let name: String? = credential.fullName.flatMap { fullName in
            let combined = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            return combined.isEmpty ? nil : combined
        }
        let email    = credential.email
        let idToken  = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }

        Task { @MainActor in
            UserDefaults.standard.set(userID, forKey: Keys.appleUserID)
            if let name { UserDefaults.standard.set(name, forKey: Keys.displayName) }

            // Exchange Apple identity token for a Supabase session.
            // The SDK stores the resulting JWT in Keychain automatically.
            if let idToken {
                do {
                    let supabaseSession = try await SupabaseClient.shared.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idToken)
                    )
                    self.session.supabaseUserId = supabaseSession.user.id.uuidString
                } catch {
                    // Supabase unavailable — local-only auth; sync will be skipped this session.
                    print("[Auth] Supabase sign-in failed: \(error.localizedDescription)")
                }
            }

            self.session.appleUserIdentifier = userID
            self.session.displayName         = name
            self.session.email               = email
            self.session.isAuthenticated     = true
            self.signInContinuation?.resume()
            self.signInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let authErr: AuthError
        if let e = error as? ASAuthorizationError, e.code == .canceled {
            authErr = .cancelled
        } else {
            authErr = .failed(error.localizedDescription)
        }
        Task { @MainActor in
            self.signInContinuation?.resume(throwing: authErr)
            self.signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

#if canImport(UIKit)
extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.keyWindow else {
            return UIWindow()
        }
        return window
    }
}
#endif
