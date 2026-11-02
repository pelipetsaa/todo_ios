import Foundation

public enum TodoStatus: CaseIterable, Sendable {
    case todo
    case inProgress
    case done
}

public struct Todo: Identifiable, Equatable, Sendable {
    /// The backend identifies tasks by UUID; the type keeps arbitrary strings out of request paths.
    public let id: UUID
    public var title: String
    public var description: String
    public var dueAt: Date
    public var status: TodoStatus
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, title: String, description: String = "", dueAt: Date,
                status: TodoStatus = .todo, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.description = description
        self.dueAt = dueAt
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TodoDraft: Equatable, Sendable {
    public var title: String
    public var description: String
    public var dueAt: Date
    public var status: TodoStatus

    /// No default due date: the current time is supplied by NewTodoDraftUseCase, never read implicitly in Domain.
    public init(title: String = "", description: String = "", dueAt: Date, status: TodoStatus = .todo) {
        self.title = title
        self.description = description
        self.dueAt = dueAt
        self.status = status
    }

    public init(todo: Todo) {
        self.init(title: todo.title, description: todo.description, dueAt: todo.dueAt, status: todo.status)
    }

    public static func nextHour(after date: Date, calendar: Calendar) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? date
    }

    public var normalized: TodoDraft {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}

public struct User: Sendable, Equatable {
    public let id: String
    public let email: String
    public init(id: String, email: String) { self.id = id; self.email = email }
}

/// Published by the auth port. `expired` differs from `signedOut` so the UI can explain an involuntary sign-out.
public enum SessionState: Equatable, Sendable {
    case signedIn
    case signedOut
    case expired

    public var isSignedIn: Bool { self == .signedIn }
}

/// One error vocabulary for every layer is a deliberate simplification for an app of this size:
/// infrastructure cases (secureStorage, configuration) live here so Presentation can map all failures to text in one place.
public enum AppError: Error, Equatable, Sendable {
    case invalidCredentials, sessionExpired, emailTaken, notFound, validation, rateLimited
    case network, server, invalidResponse, secureStorage, configuration
}
