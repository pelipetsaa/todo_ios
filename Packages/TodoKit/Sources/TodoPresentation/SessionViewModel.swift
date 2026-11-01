import Foundation
import Observation
import TodoDomain
import TodoApplication

@MainActor @Observable
public final class SessionViewModel {
    enum Phase { case restoring, signedOut, signedIn }
    private(set) var phase: Phase = .restoring
    private(set) var user: User?
    var error: String?
    private(set) var isSigningOut = false
    let auth: AuthUseCases
    let todos: TodoUseCases

    public init(auth: AuthUseCases, todos: TodoUseCases) { self.auth = auth; self.todos = todos }

    func observe() async {
        let events = await auth.observeSession()
        for await signedIn in events {
            guard !Task.isCancelled else { return }
            phase = signedIn ? .signedIn : .signedOut
            if !signedIn { user = nil }
        }
    }

    func loadUser() async {
        do { user = try await auth.currentUser() }
        catch { /* The task list reports network errors; session invalidation arrives through sessionUpdates. */ }
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        do { try await auth.signOut() }
        catch is CancellationError { }
        catch { self.error = errorKey(error) }
    }
}
