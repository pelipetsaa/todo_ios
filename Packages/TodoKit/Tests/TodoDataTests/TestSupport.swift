import Foundation
@testable import TodoData
import TodoDomain

final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: SessionTokens?
    private var failWrites = false
    init(_ tokens: SessionTokens? = nil, failWrites: Bool = false) { value = tokens; self.failWrites = failWrites }
    func load() throws -> SessionTokens? { lock.withLock { value } }
    func save(_ tokens: SessionTokens) throws {
        try lock.withLock { if failWrites { throw AppError.secureStorage }; value = tokens }
    }
    func clear() throws { lock.withLock { value = nil } }
}

actor MockTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let handler: @Sendable (URLRequest, Int) async throws -> HTTPResponse
    init(_ handler: @escaping @Sendable (URLRequest, Int) async throws -> HTTPResponse) { self.handler = handler }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        let index = requests.count - 1
        return try await handler(request, index)
    }
}

actor Latch {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() { opened = true; waiters.forEach { $0.resume() }; waiters = [] }
}

let oldTokens = SessionTokens(accessToken: "old-access", refreshToken: "old-refresh")
let newTokens = SessionTokens(accessToken: "new-access", refreshToken: "new-refresh")
let baseURL = URL(string: "https://example.com")!
let userJSON = Data(#"{"id":"user","email":"ios@example.com"}"#.utf8)
let todoID = "550e8400-e29b-41d4-a716-446655440000"

func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
func json<T: Encodable>(_ value: T) throws -> Data { try APIJSON.encoder().encode(value) }

func json(_ todo: Todo) throws -> Data { try json(TodoDTO(todo)) }
func json(_ todos: [Todo]) throws -> Data { try json(todos.map(TodoDTO.init)) }
