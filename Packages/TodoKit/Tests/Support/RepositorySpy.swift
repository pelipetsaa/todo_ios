import Foundation
import TodoDomain
import TodoApplication

public actor RepositorySpy: AuthRepository, TodoRepository {
    public private(set) var signedInEmail: String?
    public private(set) var registeredEmail: String?
    public private(set) var googleToken: String?
    public private(set) var savedDraft: TodoDraft?
    public private(set) var deletedID: String?
    public private(set) var requestedRange: DateInterval?
    public private(set) var signOutCount = 0
    public private(set) var writeCount = 0
    public private(set) var listCalls = 0
    private var error: AppError?
    private var values: [Todo]
    public init(values: [Todo] = [], error: AppError? = nil) { self.values = values; self.error = error }
    public func setError(_ error: AppError?) { self.error = error }
    public func setValues(_ values: [Todo]) { self.values = values }
    private func check() throws { if let error { throw error } }
    public func sessionUpdates() -> AsyncStream<Bool> { AsyncStream { $0.yield(true); $0.finish() } }
    public func signIn(email: String, password: String) throws { try check(); signedInEmail = email }
    public func register(email: String, password: String) throws { try check(); registeredEmail = email }
    public func signIn(googleIDToken: String) throws { try check(); googleToken = googleIDToken }
    public func currentUser() throws -> User { try check(); return User(id: "user", email: "person@example.com") }
    public func signOut() throws { signOutCount += 1; try check() }
    public func todos(in range: DateInterval) throws -> [Todo] {
        requestedRange = range; listCalls += 1; try check(); return values
    }
    public func todo(id: String) throws -> Todo {
        try check()
        guard let value = values.first(where: { $0.id == id }) else { throw AppError.notFound }
        return value
    }
    public func create(_ draft: TodoDraft) throws -> Todo {
        try check(); savedDraft = draft; writeCount += 1
        let todo = Todo(id: "created", title: draft.title, description: draft.description, dueAt: draft.dueAt, status: draft.status)
        values.append(todo); return todo
    }
    public func update(id: String, draft: TodoDraft) throws -> Todo {
        try check(); savedDraft = draft; writeCount += 1
        return Todo(id: id, title: draft.title, description: draft.description, dueAt: draft.dueAt, status: draft.status)
    }
    public func delete(id: String) throws { try check(); deletedID = id }
}

public actor GoogleIdentitySpy: GoogleIdentityProvider {
    private let token: String
    public private(set) var signOutCount = 0
    public init(token: String = "google-id-token") { self.token = token }
    public func idToken() -> String { token }
    public func signOut() { signOutCount += 1 }
}
