#if DEBUG
import Foundation
import TodoDomain
import TodoApplication

/// Explicit, isolated in-memory mode for previews and UI tests. Production always uses AuthAPI and TodoAPI.
actor DemoRepository: AuthRepository, TodoRepository {
    private var signedIn: Bool
    private var values: [Todo]
    private var observers: [UUID: AsyncStream<SessionState>.Continuation] = [:]

    init(signedIn: Bool) {
        self.signedIn = signedIn
        let start = Calendar.current.startOfDay(for: .now)
        values = [
            Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: localized("Plan the week"),
                 description: localized("Choose three things that matter most."), dueAt: start.addingTimeInterval(9 * 3600), status: .done),
            Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: localized("Make time for a walk"),
                 description: localized("A little fresh air, a fresh perspective."), dueAt: start.addingTimeInterval(12 * 3600), status: .inProgress),
            Todo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, title: localized("Read a chapter"),
                 dueAt: start.addingTimeInterval(18 * 3600))
        ]
    }
    func sessionUpdates() -> AsyncStream<SessionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<SessionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[id] = continuation
        continuation.yield(signedIn ? .signedIn : .signedOut)
        continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        return stream
    }
    private func removeObserver(_ id: UUID) { observers[id] = nil }
    private func setSession(_ value: Bool) {
        signedIn = value
        observers.values.forEach { $0.yield(value ? .signedIn : .signedOut) }
    }
    func signIn(email: String, password: String) { setSession(true) }
    func register(email: String, password: String) { setSession(true) }
    func signIn(googleIDToken: String) { setSession(true) }
    func currentUser() -> User { User(id: "demo", email: "hello@example.com") }
    func signOut() { setSession(false) }
    func todos(in range: DateInterval) -> [Todo] {
        values.filter { $0.dueAt >= range.start && $0.dueAt < range.end }.sorted { $0.dueAt < $1.dueAt }
    }
    func todo(id: Todo.ID) throws -> Todo {
        guard let value = values.first(where: { $0.id == id }) else { throw AppError.notFound }
        return value
    }
    func create(_ draft: TodoDraft) -> Todo {
        let value = Todo(id: UUID(), title: draft.normalized.title, description: draft.description,
                         dueAt: draft.dueAt, status: draft.status)
        values.append(value)
        return value
    }
    func update(id: Todo.ID, draft: TodoDraft) throws -> Todo {
        guard let index = values.firstIndex(where: { $0.id == id }) else { throw AppError.notFound }
        values[index].title = draft.normalized.title
        values[index].description = draft.description
        values[index].dueAt = draft.dueAt
        values[index].status = draft.status
        values[index].updatedAt = .now
        return values[index]
    }
    func delete(id: Todo.ID) throws {
        guard values.contains(where: { $0.id == id }) else { throw AppError.notFound }
        values.removeAll { $0.id == id }
    }
}
#endif
