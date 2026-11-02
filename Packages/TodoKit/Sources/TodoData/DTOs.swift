import Foundation
import TodoDomain

/// The backend schema stays in Data. Domain entities do not conform to Codable.
struct UserDTO: Codable {
    let id: String
    let email: String
    var domain: User { User(id: id, email: email) }
}

enum TodoStatusDTO: String, Codable {
    case todo = "TODO", inProgress = "IN_PROGRESS", done = "DONE"
    init(_ status: TodoStatus) {
        self = switch status { case .todo: .todo; case .inProgress: .inProgress; case .done: .done }
    }
    var domain: TodoStatus {
        switch self { case .todo: .todo; case .inProgress: .inProgress; case .done: .done }
    }
}

struct TodoDTO: Codable {
    let id: UUID
    let title: String
    let description: String
    let dueAt: Date
    let status: TodoStatusDTO
    let createdAt: Date
    let updatedAt: Date

    init(_ todo: Todo) {
        id = todo.id; title = todo.title; description = todo.description
        dueAt = todo.dueAt; status = TodoStatusDTO(todo.status)
        createdAt = todo.createdAt; updatedAt = todo.updatedAt
    }
    var domain: Todo {
        Todo(id: id, title: title, description: description, dueAt: dueAt,
             status: status.domain, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct TodoInputDTO: Encodable {
    let title: String
    let description: String
    let dueAt: Date
    let status: TodoStatusDTO
    init(_ draft: TodoDraft) {
        title = draft.title; description = draft.description; dueAt = draft.dueAt; status = TodoStatusDTO(draft.status)
    }
}
