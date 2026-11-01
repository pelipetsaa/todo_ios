import Observation
import Foundation
import TodoDomain
import TodoApplication

@MainActor @Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmation = ""
    private(set) var submitted = false
    private(set) var isBusy = false
    private(set) var isGoogleBusy = false
    var error: String?
    let registration: Bool
    private let useCases: AuthUseCases

    init(useCases: AuthUseCases, registration: Bool) {
        self.useCases = useCases
        self.registration = registration
    }
    var emailError: String? { submitted ? Validation.email(email)?.messageKey : nil }
    var passwordError: String? { submitted ? Validation.password(password, registration: registration)?.messageKey : nil }
    var confirmationError: String? {
        submitted && registration ? Validation.confirmation(confirmation, password: password)?.messageKey : nil
    }

    func submit() async {
        guard !isBusy else { return }
        submitted = true
        error = nil
        guard emailError == nil, passwordError == nil, confirmationError == nil else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if registration { try await useCases.register(email: email, password: password, confirmation: confirmation) }
            else { try await useCases.signIn(email: email, password: password) }
            password = ""
            confirmation = ""
        } catch is CancellationError { }
        catch { self.error = errorKey(error) }
    }

    func google() async {
        guard !isBusy else { return }
        error = nil
        isBusy = true
        isGoogleBusy = true
        defer { isBusy = false; isGoogleBusy = false }
        do {
            try await useCases.signInWithGoogle()
        } catch is CancellationError { }
        catch { self.error = errorKey(error) }
    }
}
