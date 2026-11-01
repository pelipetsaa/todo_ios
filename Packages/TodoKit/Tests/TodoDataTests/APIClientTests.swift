import Foundation
import Testing
@testable import TodoData
import TodoDomain

struct APIClientTests {
    @Test func signInEncodesCredentialsAndPersistsPair() async throws {
        let store = MemoryTokenStore()
        let transport = MockTransport { _, _ in HTTPResponse(data: try json(newTokens), status: 200) }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        try await api.signIn(email: "ios@example.com", password: "password")
        #expect(try store.load() == newTokens)
        let request = try #require(await transport.requests.first)
        #expect(request.url?.path == "/api/v1/auth/login")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: String])
        #expect(body["email"] == "ios@example.com")
        #expect(body["password"] == "password")
    }
    @Test func registrationAndGoogleUseContract() async throws {
        let transport = MockTransport { _, _ in HTTPResponse(data: try json(newTokens), status: 201) }
        let api = try APIClient(baseURL: baseURL, store: MemoryTokenStore(), transport: transport)
        try await api.register(email: "ios@example.com", password: "password")
        try await api.signIn(googleIDToken: "google-id-token")
        let requests = await transport.requests
        #expect(requests.map { $0.url!.path } == ["/api/v1/auth/register", "/api/v1/auth/google"])
        #expect(String(data: requests[1].httpBody!, encoding: .utf8)!.contains("google-id-token"))
    }
    @Test func restoresSavedSessionAndPublishesLogout() async throws {
        let store = MemoryTokenStore(oldTokens)
        let transport = MockTransport { _, _ in HTTPResponse(status: 204) }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        var iterator = await api.sessionUpdates().makeAsyncIterator()
        #expect(await iterator.next() == true)
        try await api.signOut()
        #expect(await iterator.next() == false)
        #expect(try store.load() == nil)
        let request = try #require(await transport.requests.first)
        #expect(request.url?.path == "/api/v1/auth/logout")
        #expect(String(data: request.httpBody!, encoding: .utf8)!.contains("old-refresh"))
    }
    @Test func concurrentUnauthorizedRequestsRotateOnlyOnce() async throws {
        let store = MemoryTokenStore(oldTokens)
        let transport = MockTransport { request, _ in
            if request.url!.path.hasSuffix("/refresh") {
                try await Task.sleep(for: .milliseconds(40))
                return HTTPResponse(data: try json(newTokens), status: 200)
            }
            return HTTPResponse(data: userJSON, status: request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access" ? 200 : 401)
        }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        async let first = api.currentUser()
        async let second = api.currentUser()
        let users = try await [first, second]
        #expect(users.count == 2)
        #expect(try store.load() == newTokens)
        #expect(await transport.requests.filter { $0.url!.path.hasSuffix("/refresh") }.count == 1)
    }
    @Test(arguments: [400, 401])
    func rejectedRefreshEndsSession(_ status: Int) async throws {
        let store = MemoryTokenStore(oldTokens)
        let transport = MockTransport { request, _ in HTTPResponse(status: request.url!.path.hasSuffix("/refresh") ? status : 401) }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        await #expect(throws: AppError.sessionExpired) { try await api.currentUser() }
        #expect(try store.load() == nil)
    }
    @Test func transientRefreshFailureKeepsSession() async throws {
        let store = MemoryTokenStore(oldTokens)
        let transport = MockTransport { request, _ in
            HTTPResponse(status: request.url!.path.hasSuffix("/refresh") ? 503 : 401)
        }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        await #expect(throws: AppError.server) { try await api.currentUser() }
        #expect(try store.load() == oldTokens)
    }
    @Test func networkFailureDuringRefreshKeepsSession() async throws {
        let store = MemoryTokenStore(oldTokens)
        let transport = MockTransport { request, _ in
            if request.url!.path.hasSuffix("/refresh") { throw AppError.network }
            return HTTPResponse(status: 401)
        }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        await #expect(throws: AppError.network) { try await api.currentUser() }
        #expect(try store.load() == oldTokens)
    }
    @Test func logoutDuringRefreshCannotResurrectSession() async throws {
        let started = Latch(), release = Latch()
        let store = MemoryTokenStore(oldTokens)
        let transport = MockTransport { request, _ in
            if request.url!.path.hasSuffix("/refresh") {
                await started.open()
                await release.wait()
                return HTTPResponse(data: try json(newTokens), status: 200)
            }
            return HTTPResponse(status: request.url!.path.hasSuffix("/logout") ? 204 : 401)
        }
        let api = try APIClient(baseURL: baseURL, store: store, transport: transport)
        let request = Task { try await api.currentUser() }
        await started.wait()
        try await api.signOut()
        await release.open()
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(try store.load() == nil)
    }
    @Test func offlineLogoutStillClearsLocalSession() async throws {
        let store = MemoryTokenStore(oldTokens)
        let api = try APIClient(baseURL: baseURL, store: store, transport: MockTransport { _, _ in throw AppError.network })
        await #expect(throws: AppError.network) { try await api.signOut() }
        #expect(try store.load() == nil)
    }
    @Test func safeReadsRetryButWritesDoNot() async throws {
        let transport = MockTransport { _, index in HTTPResponse(data: userJSON, status: index < 2 ? 503 : 200) }
        let api = try APIClient(baseURL: baseURL, store: MemoryTokenStore(oldTokens), transport: transport, retryDelay: 0)
        #expect(try await api.currentUser().email == "ios@example.com")
        #expect(await transport.requests.count == 3)
        let failing = MockTransport { _, _ in HTTPResponse(status: 503) }
        let writer = try APIClient(baseURL: baseURL, store: MemoryTokenStore(oldTokens), transport: failing, retryDelay: 0)
        await #expect(throws: AppError.server) { try await writer.create(TodoDraft(title: "Create only once")) }
        #expect(await failing.requests.count == 1)
    }
    @Test func listUsesHalfOpenRangeAndMapsDTOs() async throws {
        let start = instant("2026-11-01T00:00:00Z"), end = instant("2026-11-02T00:00:00Z")
        let values = [Todo(id: "2", title: "Later", dueAt: start.addingTimeInterval(200)), Todo(id: "1", title: "Earlier", dueAt: start.addingTimeInterval(100))]
        let transport = MockTransport { _, _ in HTTPResponse(data: try json(values), status: 200) }
        let api = try APIClient(baseURL: baseURL, store: MemoryTokenStore(oldTokens), transport: transport)
        #expect(try await api.todos(in: DateInterval(start: start, end: end)).map(\.id) == ["2", "1"])
        let request = try #require(await transport.requests.first)
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(query.first { $0.name == "from" }?.value == "2026-11-01T00:00:00Z")
        #expect(query.first { $0.name == "to" }?.value == "2026-11-02T00:00:00Z")
    }
    @Test func crudUsesCorrectMethodsAndDTOs() async throws {
        let todo = Todo(id: todoID, title: "Task", dueAt: instant("2026-11-01T12:00:00Z"))
        let transport = MockTransport { request, _ in
            HTTPResponse(data: request.httpMethod == "DELETE" ? Data() : try json(todo), status: request.httpMethod == "DELETE" ? 204 : 200)
        }
        let api = try APIClient(baseURL: baseURL, store: MemoryTokenStore(oldTokens), transport: transport)
        _ = try await api.create(TodoDraft(title: "Task"))
        _ = try await api.todo(id: todoID)
        _ = try await api.update(id: todoID, draft: TodoDraft(title: "Task", status: .done))
        try await api.delete(id: todoID)
        let requests = await transport.requests
        #expect(requests.map(\.httpMethod) == ["POST", "GET", "PUT", "DELETE"])
        let body = try #require(JSONSerialization.jsonObject(with: requests[0].httpBody!) as? [String: Any])
        #expect(body["title"] as? String == "Task")
        #expect(body["status"] as? String == "TODO")
        #expect(requests[1].url!.path == "/api/v1/todos/\(todoID)")
    }
    @Test(arguments: [(400, AppError.validation), (404, .notFound), (409, .emailTaken), (429, .rateLimited), (500, .server)])
    func mapsHTTPFailures(_ pair: (Int, AppError)) async throws {
        let api = try APIClient(baseURL: baseURL, store: MemoryTokenStore(oldTokens), transport: MockTransport { _, _ in HTTPResponse(status: pair.0) })
        await #expect(throws: pair.1) { try await api.currentUser() }
    }
    @Test func invalidResponseDoesNotDestroySession() async throws {
        let store = MemoryTokenStore(oldTokens)
        let api = try APIClient(baseURL: baseURL, store: store, transport: MockTransport { _, _ in HTTPResponse(data: Data("bad".utf8), status: 200) })
        await #expect(throws: AppError.invalidResponse) { try await api.currentUser() }
        #expect(try store.load() == oldTokens)
    }
    @Test func unauthenticatedAndInvalidIDsNeverReachTransport() async throws {
        let transport = MockTransport { _, _ in HTTPResponse(status: 200) }
        let api = try APIClient(baseURL: baseURL, store: MemoryTokenStore(), transport: transport)
        await #expect(throws: AppError.sessionExpired) { try await api.currentUser() }
        await #expect(throws: AppError.validation) { try await api.delete(id: "../me") }
        #expect(await transport.requests.isEmpty)
    }
    @Test func storageFailureDoesNotPublishSignedIn() async throws {
        let store = MemoryTokenStore(failWrites: true)
        let api = try APIClient(baseURL: baseURL, store: store, transport: MockTransport { _, _ in HTTPResponse(data: try json(newTokens), status: 200) })
        await #expect(throws: AppError.secureStorage) { try await api.signIn(email: "a@b.com", password: "password") }
        #expect(try store.load() == nil)
    }
    @Test(arguments: ["http://example.com", "https://user:pass@example.com", "https://example.com?token=bad"])
    func rejectsUnsafeConfiguration(_ value: String) {
        #expect(throws: AppError.configuration) { try APIClient(baseURL: URL(string: value)!, store: MemoryTokenStore()) }
    }
}
