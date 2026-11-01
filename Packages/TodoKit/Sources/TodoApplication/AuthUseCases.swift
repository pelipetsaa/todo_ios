import Foundation
import TodoDomain

/// Platform boundary: Application knows neither UIKit nor the Google SDK.
public protocol GoogleIdentityProvider: Sendable {
    func idToken() async throws -> String
    func signOut() async
}

public struct SignInUseCase: Sendable {
    private let repository: any AuthRepository
    public init(repository: any AuthRepository) { self.repository = repository }
    public func callAsFunction(email: String, password: String) async throws {
        try requireValid([Validation.email(email), Validation.password(password, registration: false)])
        try await repository.signIn(email: normalizedEmail(email), password: password)
    }
}

public struct RegisterUseCase: Sendable {
    private let repository: any AuthRepository
    public init(repository: any AuthRepository) { self.repository = repository }
    public func callAsFunction(email: String, password: String, confirmation: String) async throws {
        try requireValid([Validation.email(email), Validation.password(password, registration: true),
                          Validation.confirmation(confirmation, password: password)])
        try await repository.register(email: normalizedEmail(email), password: password)
    }
}

public struct SignInWithGoogleUseCase: Sendable {
    private let repository: any AuthRepository
    private let identity: any GoogleIdentityProvider
    public init(repository: any AuthRepository, identity: any GoogleIdentityProvider) {
        self.repository = repository; self.identity = identity
    }
    public func callAsFunction() async throws {
        let token = try await identity.idToken()
        try Task.checkCancellation()
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppError.invalidResponse }
        try await repository.signIn(googleIDToken: token)
    }
}

public struct SignOutUseCase: Sendable {
    private let repository: any AuthRepository
    private let identity: any GoogleIdentityProvider
    public init(repository: any AuthRepository, identity: any GoogleIdentityProvider) {
        self.repository = repository; self.identity = identity
    }
    public func callAsFunction() async throws {
        // Also discard the platform's Google session when remote revocation fails after local sign-out.
        do { try await repository.signOut() }
        catch { await identity.signOut(); throw error }
        await identity.signOut()
    }
}

public struct ObserveSessionUseCase: Sendable {
    private let repository: any AuthRepository
    public init(repository: any AuthRepository) { self.repository = repository }
    public func callAsFunction() async -> AsyncStream<Bool> { await repository.sessionUpdates() }
}

public struct GetCurrentUserUseCase: Sendable {
    private let repository: any AuthRepository
    public init(repository: any AuthRepository) { self.repository = repository }
    public func callAsFunction() async throws -> User { try await repository.currentUser() }
}

/// Immutable input to the presentation layer; no repository or infrastructure is exposed.
public struct AuthUseCases: Sendable {
    public let signIn: SignInUseCase
    public let register: RegisterUseCase
    public let signInWithGoogle: SignInWithGoogleUseCase
    public let signOut: SignOutUseCase
    public let observeSession: ObserveSessionUseCase
    public let currentUser: GetCurrentUserUseCase
    public init(repository: any AuthRepository, identity: any GoogleIdentityProvider) {
        signIn = SignInUseCase(repository: repository)
        register = RegisterUseCase(repository: repository)
        signInWithGoogle = SignInWithGoogleUseCase(repository: repository, identity: identity)
        signOut = SignOutUseCase(repository: repository, identity: identity)
        observeSession = ObserveSessionUseCase(repository: repository)
        currentUser = GetCurrentUserUseCase(repository: repository)
    }
}

private func normalizedEmail(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

func requireValid(_ issues: [ValidationIssue?]) throws {
    let failures = issues.compactMap { $0 }
    if !failures.isEmpty { throw ValidationFailure(issues: failures) }
}
