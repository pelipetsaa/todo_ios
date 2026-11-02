import Foundation
import Testing
import TodoDomain
import TodoApplication
import TodoTestSupport

struct UseCaseTests {
    @Test func signInNormalizesEmailBeforeCallingPort() async throws {
        let repository = RepositorySpy()
        try await SignInUseCase(repository: repository)(email: "  PERSON@Example.com\n", password: "legacy")
        #expect(await repository.signedInEmail == "person@example.com")
    }
    @Test func invalidSignInDoesNotCallPort() async {
        let repository = RepositorySpy()
        await #expect(throws: ValidationFailure(issues: [.emailInvalid, .passwordBlank])) {
            try await SignInUseCase(repository: repository)(email: "invalid", password: "")
        }
        #expect(await repository.signedInEmail == nil)
    }
    @Test func registrationEnforcesPasswordAndConfirmationOutsideUI() async throws {
        let repository = RepositorySpy()
        let register = RegisterUseCase(repository: repository)
        await #expect(throws: ValidationFailure(issues: [.passwordTooShort, .passwordMismatch])) {
            try await register(email: "person@example.com", password: "short", confirmation: "different")
        }
        #expect(await repository.registeredEmail == nil)
        try await register(email: " PERSON@example.com ", password: "password", confirmation: "password")
        #expect(await repository.registeredEmail == "person@example.com")
    }
    @Test func googleUsesIdentityPortAndExchangesToken() async throws {
        let repository = RepositorySpy()
        try await SignInWithGoogleUseCase(repository: repository, identity: GoogleIdentitySpy())()
        #expect(await repository.googleToken == "google-id-token")
    }
    @Test func emptyGoogleTokenIsRejectedBeforeExchange() async {
        let repository = RepositorySpy()
        await #expect(throws: AppError.invalidResponse) {
            try await SignInWithGoogleUseCase(repository: repository, identity: GoogleIdentitySpy(token: " "))()
        }
        #expect(await repository.googleToken == nil)
    }
    @Test func signOutClearsIdentityEvenWhenRevocationFails() async {
        let repository = RepositorySpy(error: .network)
        let google = GoogleIdentitySpy()
        await #expect(throws: AppError.network) { try await SignOutUseCase(repository: repository, identity: google)() }
        #expect(await repository.signOutCount == 1)
        #expect(await google.signOutCount == 1)
    }
    @Test func listCalculatesLocalWindowAndSortsRepositoryResults() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-11-01T13:00:00Z")!
        let later = UUID(), earlier = UUID()
        let repository = RepositorySpy(values: [Todo(id: later, title: "Later", dueAt: now),
                                                Todo(id: earlier, title: "Earlier", dueAt: now.addingTimeInterval(-3600))])
        let useCase = GetTodosUseCase(repository: repository, now: { now }, timeZone: { TimeZone(identifier: "Europe/Warsaw")! })
        #expect(try await useCase(period: .week).map(\.id) == [earlier, later])
        let range = try #require(await repository.requestedRange)
        #expect(range == TodoPeriod.week.range(at: now, timeZone: TimeZone(identifier: "Europe/Warsaw")!))
    }
    @Test(arguments: [("2026-11-01T10:15:00Z", "2026-11-01T11:00:00Z"),
                      ("2026-11-01T22:59:59Z", "2026-11-01T23:00:00Z"),
                      ("2026-11-01T23:10:00Z", "2026-11-01T23:59:00Z"),
                      ("2026-12-31T23:59:30Z", "2026-12-31T23:59:00Z")])
    func newDraftStaysInTodayNearMidnight(_ pair: (String, String)) {
        let now = ISO8601DateFormatter().date(from: pair.0)!
        let draft = NewTodoDraftUseCase(now: { now }, timeZone: { TimeZone(identifier: "UTC")! })()
        #expect(draft.dueAt == ISO8601DateFormatter().date(from: pair.1)!)
        #expect(TodoPeriod.today.range(at: now, timeZone: TimeZone(identifier: "UTC")!).contains(draft.dueAt))
    }
    @Test func newDraftUsesLocalDayBoundary() {
        // 22:30 UTC is already 23:30 in Warsaw, so the default must be 23:59 local time, not 23:00 UTC.
        let now = ISO8601DateFormatter().date(from: "2026-11-01T22:30:00Z")!
        let draft = NewTodoDraftUseCase(now: { now }, timeZone: { TimeZone(identifier: "Europe/Warsaw")! })()
        #expect(draft.dueAt == ISO8601DateFormatter().date(from: "2026-11-01T22:59:00Z")!)
    }
    @Test func editorChangesKeepListInPeriodAndOrder() {
        let now = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
        let list = GetTodosUseCase(repository: RepositorySpy(), now: { now }, timeZone: { TimeZone(identifier: "UTC")! })
        let morning = Todo(id: UUID(), title: "Morning", dueAt: now.addingTimeInterval(-3 * 3600))
        let evening = Todo(id: UUID(), title: "Evening", dueAt: now.addingTimeInterval(6 * 3600))
        let noon = Todo(id: UUID(), title: "Noon", dueAt: now)
        // A new task is inserted in time order.
        #expect(list.applying(.saved(noon), to: [morning, evening], period: .today).map(\.id) == [morning.id, noon.id, evening.id])
        // An edit that moves a task out of the window removes it from this list.
        var tomorrow = noon
        tomorrow.dueAt = now.addingTimeInterval(24 * 3600)
        #expect(list.applying(.saved(tomorrow), to: [morning, noon, evening], period: .today).map(\.id) == [morning.id, evening.id])
        // The window end is exclusive, like the backend query.
        var midnight = noon
        midnight.dueAt = ISO8601DateFormatter().date(from: "2026-11-02T00:00:00Z")!
        #expect(list.applying(.saved(midnight), to: [morning], period: .today).map(\.id) == [morning.id])
        #expect(list.applying(.deleted(id: morning.id), to: [morning, evening], period: .today).map(\.id) == [evening.id])
    }
    @Test func invalidDraftCannotBypassValidationUsingAnotherPresentation() async {
        let repository = RepositorySpy()
        let invalid = TodoDraft(title: " ", description: String(repeating: "a", count: 2001), dueAt: .now)
        let expected = ValidationFailure(issues: [.titleBlank, .descriptionTooLong])
        await #expect(throws: expected) { try await CreateTodoUseCase(repository: repository)(invalid) }
        await #expect(throws: expected) { try await UpdateTodoUseCase(repository: repository)(id: UUID(), draft: invalid) }
        #expect(await repository.writeCount == 0)
    }
    @Test func writesNormalizeTitleAndPreserveOtherFields() async throws {
        let repository = RepositorySpy()
        let draft = TodoDraft(title: "  Focus\n", description: " Keep spacing ", dueAt: .now, status: .inProgress)
        _ = try await CreateTodoUseCase(repository: repository)(draft)
        #expect(await repository.savedDraft == draft.normalized)
        _ = try await UpdateTodoUseCase(repository: repository)(id: UUID(), draft: draft)
        #expect(await repository.savedDraft?.description == " Keep spacing ")
        #expect(await repository.writeCount == 2)
    }
    @Test func detailDeleteSessionAndProfileUsePorts() async throws {
        let todo = Todo(id: UUID(), title: "Task", dueAt: .now)
        let repository = RepositorySpy(values: [todo])
        #expect(try await GetTodoUseCase(repository: repository)(id: todo.id) == todo)
        try await DeleteTodoUseCase(repository: repository)(id: todo.id)
        #expect(await repository.deletedID == todo.id)
        #expect(try await GetCurrentUserUseCase(repository: repository)().email == "person@example.com")
        var events = await ObserveSessionUseCase(repository: repository)().makeAsyncIterator()
        #expect(await events.next() == .signedIn)
    }
}
