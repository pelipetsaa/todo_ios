import UIKit
import GoogleSignIn
import TodoDomain
import TodoApplication

@MainActor
struct GoogleSignInService: GoogleIdentityProvider {
    func idToken() async throws -> String {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty, !clientID.contains("$("),
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.keyWindow?.rootViewController else { throw AppError.configuration }
        while let presented = presenter.presentedViewController { presenter = presented }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let token = result.user.idToken?.tokenString else { throw AppError.invalidResponse }
            return token
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue {
            throw CancellationError()
        }
    }

    static func handle(_ url: URL) { _ = GIDSignIn.sharedInstance.handle(url) }
    func signOut() async { GIDSignIn.sharedInstance.signOut() }
}
