import Foundation
import TodoDomain

/// Auth endpoints over the shared APISession.
public struct AuthAPI: AuthRepository {
    private let session: APISession
    public init(session: APISession) { self.session = session }

    public func sessionUpdates() async -> AsyncStream<SessionState> { await session.updates() }

    public func signIn(email: String, password: String) async throws {
        try await session.authenticate(path: "auth/login", body: Credentials(email: email, password: password))
    }
    public func register(email: String, password: String) async throws {
        try await session.authenticate(path: "auth/register", body: Credentials(email: email, password: password))
    }
    public func signIn(googleIDToken: String) async throws {
        try await session.authenticate(path: "auth/google", body: GoogleToken(idToken: googleIDToken))
    }
    public func currentUser() async throws -> User {
        let dto: UserDTO = try APIJSON.decode(await session.authorized("me"))
        return dto.domain
    }
    public func signOut() async throws { try await session.signOut() }
}

private struct Credentials: Encodable, Sendable {
    let email: String
    let password: String
}
private struct GoogleToken: Encodable, Sendable { let idToken: String }
