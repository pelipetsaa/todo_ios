import Foundation
import TodoDomain

/// A single actor owns the session, serializes token rotation and prevents stale requests from reviving a logged-out session.
public actor APIClient: AuthRepository, TodoRepository {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let store: any TokenStore
    private let retryDelay: UInt64
    private var tokens: SessionTokens?
    private var generation = 0
    private var refreshTask: Task<SessionTokens, Error>?
    private var refreshID: UUID?
    private var observers: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init(baseURL: URL, store: any TokenStore = KeychainTokenStore(),
                transport: any HTTPTransport = URLSessionTransport(), retryDelay: UInt64 = 300_000_000) throws {
        let local = ["localhost", "127.0.0.1", "::1"].contains(baseURL.host ?? "")
        guard baseURL.host != nil, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil,
              baseURL.scheme == "https" || (baseURL.scheme == "http" && local) else { throw AppError.configuration }
        self.baseURL = baseURL
        self.store = store
        self.transport = transport
        self.retryDelay = retryDelay
        self.tokens = try store.load()
    }

    public func sessionUpdates() -> AsyncStream<Bool> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[id] = continuation
        continuation.yield(tokens != nil)
        continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        return stream
    }

    private func removeObserver(_ id: UUID) { observers[id] = nil }
    private func publishSession() { for observer in observers.values { observer.yield(tokens != nil) } }

    public func signIn(email: String, password: String) async throws {
        try await authenticate(path: "auth/login", body: Credentials(email: email, password: password))
    }
    public func register(email: String, password: String) async throws {
        try await authenticate(path: "auth/register", body: Credentials(email: email, password: password))
    }
    public func signIn(googleIDToken: String) async throws {
        try await authenticate(path: "auth/google", body: GoogleToken(idToken: googleIDToken))
    }

    private func authenticate<T: Encodable & Sendable>(path: String, body: T) async throws {
        let requestGeneration = generation
        let response = try await send(makeRequest(path, method: "POST", body: APIJSON.encoder().encode(body)))
        try Task.checkCancellation()
        guard requestGeneration == generation else { throw CancellationError() }
        if response.status == 401 { throw AppError.invalidCredentials }
        try check(response)
        let pair: SessionTokens = try decode(response)
        try store.save(pair)
        tokens = pair
        generation += 1
        publishSession()
    }

    public func signOut() async throws {
        let oldTokens = tokens
        // Local sign-out succeeds even when revocation cannot reach the server. A storage failure stays visible.
        try endSession()
        if let oldTokens {
            // Revocation is best effort: the device is already signed out, so server and network failures are not reported.
            _ = try? await send(makeRequest("auth/logout", method: "POST",
                body: APIJSON.encoder().encode(RefreshToken(refreshToken: oldTokens.refreshToken))))
        }
    }

    private func endSession() throws {
        try store.clear()
        tokens = nil
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
        publishSession()
    }

    public func currentUser() async throws -> User {
        let dto: UserDTO = try decode(await authorized("me"))
        return dto.domain
    }

    public func todos(in range: DateInterval) async throws -> [Todo] {
        let query = [URLQueryItem(name: "from", value: range.start.ISO8601Format()),
                     URLQueryItem(name: "to", value: range.end.ISO8601Format())]
        let values: [TodoDTO] = try decode(await authorized("todos", query: query))
        return values.map(\.domain)
    }
    public func todo(id: String) async throws -> Todo {
        let dto: TodoDTO = try decode(await authorized("todos/\(try safeID(id))"))
        return dto.domain
    }
    public func create(_ draft: TodoDraft) async throws -> Todo {
        let dto: TodoDTO = try decode(await authorized("todos", method: "POST", body: APIJSON.encoder().encode(TodoInputDTO(draft))))
        return dto.domain
    }
    public func update(id: String, draft: TodoDraft) async throws -> Todo {
        let dto: TodoDTO = try decode(await authorized("todos/\(try safeID(id))", method: "PUT", body: APIJSON.encoder().encode(TodoInputDTO(draft))))
        return dto.domain
    }
    public func delete(id: String) async throws { _ = try await authorized("todos/\(try safeID(id))", method: "DELETE") }

    private func safeID(_ id: String) throws -> String {
        guard UUID(uuidString: id) != nil else { throw AppError.validation }
        return id
    }

    private func authorized(_ path: String, method: String = "GET", body: Data? = nil,
                            query: [URLQueryItem] = []) async throws -> HTTPResponse {
        guard let initialTokens = tokens else { throw AppError.sessionExpired }
        let requestGeneration = generation
        var request = try makeRequest(path, method: method, body: body, query: query)
        request.setValue("Bearer \(initialTokens.accessToken)", forHTTPHeaderField: "Authorization")
        var response = try await send(request)
        try Task.checkCancellation()
        guard generation == requestGeneration else { throw CancellationError() }
        if response.status == 401 {
            // Another request may already have rotated the pair while this request was in flight.
            let pair: SessionTokens
            if let current = tokens, current.accessToken != initialTokens.accessToken { pair = current }
            else { pair = try await refresh(expectedGeneration: requestGeneration) }
            guard generation == requestGeneration else { throw CancellationError() }
            request.setValue("Bearer \(pair.accessToken)", forHTTPHeaderField: "Authorization")
            response = try await send(request)
            try Task.checkCancellation()
            guard generation == requestGeneration else { throw CancellationError() }
            if response.status == 401 { try endSession() }
        }
        try check(response)
        return response
    }

    private func refresh(expectedGeneration: Int) async throws -> SessionTokens {
        guard let current = tokens else { throw AppError.sessionExpired }
        let task: Task<SessionTokens, Error>
        let id: UUID
        if let existing = refreshTask, let existingID = refreshID { task = existing; id = existingID }
        else {
            let request = try makeRequest("auth/refresh", method: "POST",
                                          body: APIJSON.encoder().encode(RefreshToken(refreshToken: current.refreshToken)))
            let transport = transport
            task = Task {
                let response = try await transport.send(request)
                if [400, 401].contains(response.status) { throw AppError.sessionExpired }
                try Self.validateResponse(response)
                guard let pair = try? APIJSON.decoder().decode(SessionTokens.self, from: response.data) else {
                    throw AppError.invalidResponse
                }
                return pair
            }
            id = UUID()
            refreshTask = task
            refreshID = id
        }
        defer { if refreshID == id { refreshTask = nil; refreshID = nil } }
        do {
            let pair = try await task.value
            guard generation == expectedGeneration else { throw CancellationError() }
            // The server has already rotated the pair: keep it in memory even if persisting it fails.
            if tokens != pair { tokens = pair; try store.save(pair) }
            return pair
        } catch {
            if generation == expectedGeneration, error as? AppError == .sessionExpired { try endSession() }
            throw error
        }
    }

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil,
                             query: [URLQueryItem] = []) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/\(path)"), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw AppError.configuration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }

    private func send(_ request: URLRequest) async throws -> HTTPResponse {
        var response = try await transport.send(request)
        if request.httpMethod == "GET" {
            for attempt in 1...2 where [502, 503, 504].contains(response.status) {
                try await Task.sleep(nanoseconds: retryDelay * UInt64(attempt))
                response = try await transport.send(request)
            }
        }
        return response
    }
    private func check(_ response: HTTPResponse) throws { try Self.validateResponse(response) }
    private static func validateResponse(_ response: HTTPResponse) throws {
        switch response.status {
        case 200..<300: return
        case 400: throw AppError.validation
        case 401: throw AppError.sessionExpired
        case 404: throw AppError.notFound
        case 409: throw AppError.emailTaken
        case 429: throw AppError.rateLimited
        default: throw AppError.server
        }
    }
    private func decode<T: Decodable>(_ response: HTTPResponse) throws -> T {
        do { return try APIJSON.decoder().decode(T.self, from: response.data) }
        catch { throw AppError.invalidResponse }
    }
}

private struct Credentials: Encodable, Sendable {
    let email: String
    let password: String
    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}
private struct GoogleToken: Encodable, Sendable { let idToken: String }
private struct RefreshToken: Encodable, Sendable { let refreshToken: String }
