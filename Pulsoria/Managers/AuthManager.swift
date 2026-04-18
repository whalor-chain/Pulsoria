import Foundation
import AuthenticationServices
import Combine
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool = false
    @Published var didPassSignIn: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var appleUserID: String = ""

    private init() {
        loadUser()
    }

    // MARK: - Handle Sign In Result

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }

            let userID = credential.user

            // Apple only provides name/email on FIRST sign in
            if let fullName = credential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty {
                    userName = name
                    UserDefaults.standard.set(name, forKey: UserDefaultsKey.appleUserName)
                }
            }

            if let email = credential.email {
                userEmail = email
                UserDefaults.standard.set(email, forKey: UserDefaultsKey.appleUserEmail)
            }

            appleUserID = userID
            isSignedIn = true
            didPassSignIn = true
            UserDefaults.standard.set(userID, forKey: UserDefaultsKey.appleUserID)
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.appleSignedIn)
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.didPassSignIn)

        case .failure:
            break
        }
    }

    // MARK: - Check Credential State

    func checkCredentialState() {
        guard !appleUserID.isEmpty else { return }
        let userID = appleUserID
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { state, _ in
            Task { @MainActor [weak self] in
                if state == .revoked || state == .notFound {
                    self?.signOut()
                }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        isSignedIn = false
        userName = ""
        userEmail = ""
        appleUserID = ""
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.appleUserID)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.appleUserName)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.appleUserEmail)
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.appleSignedIn)
    }

    // MARK: - Load

    private func loadUser() {
        isSignedIn = UserDefaults.standard.bool(forKey: UserDefaultsKey.appleSignedIn)
        didPassSignIn = UserDefaults.standard.bool(forKey: UserDefaultsKey.didPassSignIn)
        appleUserID = UserDefaults.standard.string(forKey: UserDefaultsKey.appleUserID) ?? ""
        userName = UserDefaults.standard.string(forKey: UserDefaultsKey.appleUserName) ?? ""
        userEmail = UserDefaults.standard.string(forKey: UserDefaultsKey.appleUserEmail) ?? ""
    }
}
