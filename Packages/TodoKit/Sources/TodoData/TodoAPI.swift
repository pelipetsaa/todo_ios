import Foundation
import TodoDomain

/// Todo endpoints and DTO mapping over the shared APISession.
public struct TodoAPI: TodoRepository {
    private let session: APISession
    public init(session: APISession) { self.session = session }

    public func todos(in range: DateInterval) async throws -> [Todo] {
        let query = [URLQueryItem(name: "from", value: range.start.ISO8601Format()),
                     URLQueryItem(name: "to", value: range.end.ISO8601Format())]
        let values: [TodoDTO] = try APIJSON.decode(await session.authorized("todos", query: query))
        return values.map(\.domain)
    }
    public func todo(id: Todo.ID) async throws -> Todo {
        let dto: TodoDTO = try APIJSON.decode(await session.authorized(path(id)))
        return dto.domain
    }
    public func create(_ draft: TodoDraft) async throws -> Todo {
        let dto: TodoDTO = try APIJSON.decode(await session.authorized(
            "todos", method: "POST", body: APIJSON.encoder().encode(TodoInputDTO(draft))))
        return dto.domain
    }
    public func update(id: Todo.ID, draft: TodoDraft) async throws -> Todo {
        let dto: TodoDTO = try APIJSON.decode(await session.authorized(
            path(id), method: "PUT", body: APIJSON.encoder().encode(TodoInputDTO(draft))))
        return dto.domain
    }
    public func delete(id: Todo.ID) async throws { _ = try await session.authorized(path(id), method: "DELETE") }

    // The backend prints UUIDs in lower case; keep paths identical to the ones it generates.
    private func path(_ id: Todo.ID) -> String { "todos/\(id.uuidString.lowercased())" }
}
