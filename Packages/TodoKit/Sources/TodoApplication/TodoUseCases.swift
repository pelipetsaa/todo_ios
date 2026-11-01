import Foundation
import TodoDomain

public struct GetTodosUseCase: Sendable {
    private let repository: any TodoRepository
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone
    public init(repository: any TodoRepository, now: @escaping @Sendable () -> Date = { .now },
                timeZone: @escaping @Sendable () -> TimeZone = { .current }) {
        self.repository = repository; self.now = now; self.timeZone = timeZone
    }
    public func callAsFunction(period: TodoPeriod) async throws -> [Todo] {
        let values = try await repository.todos(in: period.range(at: now(), timeZone: timeZone()))
        return values.sorted { ($0.dueAt, $0.id) < ($1.dueAt, $1.id) }
    }
}

public struct GetTodoUseCase: Sendable {
    private let repository: any TodoRepository
    public init(repository: any TodoRepository) { self.repository = repository }
    public func callAsFunction(id: String) async throws -> Todo { try await repository.todo(id: id) }
}

public struct CreateTodoUseCase: Sendable {
    private let repository: any TodoRepository
    public init(repository: any TodoRepository) { self.repository = repository }
    public func callAsFunction(_ draft: TodoDraft) async throws -> Todo {
        try requireValid([Validation.title(draft.title), Validation.description(draft.description)])
        return try await repository.create(draft.normalized)
    }
}

public struct UpdateTodoUseCase: Sendable {
    private let repository: any TodoRepository
    public init(repository: any TodoRepository) { self.repository = repository }
    public func callAsFunction(id: String, draft: TodoDraft) async throws -> Todo {
        try requireValid([Validation.title(draft.title), Validation.description(draft.description)])
        return try await repository.update(id: id, draft: draft.normalized)
    }
}

public struct DeleteTodoUseCase: Sendable {
    private let repository: any TodoRepository
    public init(repository: any TodoRepository) { self.repository = repository }
    public func callAsFunction(id: String) async throws { try await repository.delete(id: id) }
}

public struct NewTodoDraftUseCase: Sendable {
    private let now: @Sendable () -> Date
    public init(now: @escaping @Sendable () -> Date = { .now }) { self.now = now }
    public func callAsFunction() -> TodoDraft { TodoDraft(dueAt: TodoDraft.nextHour(after: now())) }
}

public struct TodoUseCases: Sendable {
    public let list: GetTodosUseCase
    public let detail: GetTodoUseCase
    public let create: CreateTodoUseCase
    public let update: UpdateTodoUseCase
    public let delete: DeleteTodoUseCase
    public let newDraft: NewTodoDraftUseCase
    public init(repository: any TodoRepository, now: @escaping @Sendable () -> Date = { .now },
                timeZone: @escaping @Sendable () -> TimeZone = { .current }) {
        list = GetTodosUseCase(repository: repository, now: now, timeZone: timeZone)
        detail = GetTodoUseCase(repository: repository)
        create = CreateTodoUseCase(repository: repository)
        update = UpdateTodoUseCase(repository: repository)
        delete = DeleteTodoUseCase(repository: repository)
        newDraft = NewTodoDraftUseCase(now: now)
    }
}
