import Foundation

public protocol AuthRepository: Sendable {
    func sessionUpdates() async -> AsyncStream<SessionState>
    func signIn(email: String, password: String) async throws
    func register(email: String, password: String) async throws
    func signIn(googleIDToken: String) async throws
    func currentUser() async throws -> User
    func signOut() async throws
}

public protocol TodoRepository: Sendable {
    func todos(in range: DateInterval) async throws -> [Todo]
    func todo(id: Todo.ID) async throws -> Todo
    func create(_ draft: TodoDraft) async throws -> Todo
    func update(id: Todo.ID, draft: TodoDraft) async throws -> Todo
    func delete(id: Todo.ID) async throws
}
