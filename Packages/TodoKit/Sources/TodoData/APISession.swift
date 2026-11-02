import Foundation
import TodoDomain

/// Owns the token pair: persistence, rotation and authorized requests. One actor serializes token rotation,
/// and `generation` prevents stale responses from reviving a session that has ended in the meantime.
/// Endpoint knowledge and DTO mapping live in AuthAPI and TodoAPI.
public actor APISession {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let store: any TokenStore
    private let retryDelay: UInt64
    private var tokens: SessionTokens?
    private var state: SessionState
    private var generation = 0
    private var refreshTask: Task<SessionTokens, Error>?
    private var refreshID: UUID?
    private var observers: [UUID: AsyncStream<SessionState>.Continuation] = [:]

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
        let saved = try store.load()
        self.tokens = saved
        self.state = saved == nil ? .signedOut : .signedIn
    }

    func updates() -> AsyncStream<SessionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<SessionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[id] = continuation
        // A late subscriber learns the current state, not an expiry that happened before it subscribed.
        continuation.yield(state == .expired ? .signedOut : state)
        continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        return stream
    }

    private func removeObserver(_ id: UUID) { observers[id] = nil }
    private func publish(_ newState: SessionState) {
        state = newState
        for observer in observers.values { observer.yield(newState) }
    }

    func authenticate<T: Encodable & Sendable>(path: String, body: T) async throws {
        let requestGeneration = generation
        let response = try await send(request(path, method: "POST", body: APIJSON.encoder().encode(body)))
        try Task.checkCancellation()
        guard requestGeneration == generation else { throw CancellationError() }
        if response.status == 401 { throw AppError.invalidCredentials }
        try APIJSON.validate(response)
        let pair: SessionTokens = try APIJSON.decode(response)
        try store.save(pair)
        tokens = pair
        generation += 1
        publish(.signedIn)
    }

    func signOut() async throws {
        let oldTokens = tokens
        // Local sign-out succeeds even when revocation cannot reach the server. A storage failure stays visible.
        try endSession(.signedOut)
        if let oldTokens {
            // Revocation is best effort: the device is already signed out, so server and network failures are not reported.
            _ = try? await send(request("auth/logout", method: "POST",
                body: APIJSON.encoder().encode(RefreshToken(refreshToken: oldTokens.refreshToken))))
        }
    }

    private func endSession(_ reason: SessionState) throws {
        try store.clear()
        tokens = nil
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
        publish(reason)
    }

    func authorized(_ path: String, method: String = "GET", body: Data? = nil,
                    query: [URLQueryItem] = []) async throws -> HTTPResponse {
        guard let initialTokens = tokens else { throw AppError.sessionExpired }
        let requestGeneration = generation
        var request = try request(path, method: method, body: body, query: query)
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
            if response.status == 401 { try endSession(.expired) }
        }
        try APIJSON.validate(response)
        return response
    }

    private func refresh(expectedGeneration: Int) async throws -> SessionTokens {
        guard let current = tokens else { throw AppError.sessionExpired }
        let task: Task<SessionTokens, Error>
        let id: UUID
        if let existing = refreshTask, let existingID = refreshID { task = existing; id = existingID }
        else {
            let request = try request("auth/refresh", method: "POST",
                                      body: APIJSON.encoder().encode(RefreshToken(refreshToken: current.refreshToken)))
            let transport = transport
            task = Task {
                let response = try await transport.send(request)
                if [400, 401].contains(response.status) { throw AppError.sessionExpired }
                try APIJSON.validate(response)
                let pair: SessionTokens = try APIJSON.decode(response)
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
            if generation == expectedGeneration, error as? AppError == .sessionExpired { try endSession(.expired) }
            throw error
        }
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil,
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
}

private struct RefreshToken: Encodable, Sendable { let refreshToken: String }
