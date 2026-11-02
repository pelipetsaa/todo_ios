import Foundation
import Testing
import TodoDomain
import TodoApplication
import TodoTestSupport
@testable import TodoPresentation

@MainActor
struct ViewModelTests {
    @Test func authShowsFieldErrorsAndDoesNotSubmitInvalidForm() async {
        let repository = RepositorySpy()
        let model = AuthViewModel(useCases: AuthUseCases(repository: repository, identity: GoogleIdentitySpy()), registration: true)
        await model.submit()
        #expect(model.emailError == ValidationIssue.emailBlank.messageKey)
        #expect(model.passwordError == ValidationIssue.passwordBlank.messageKey)
        #expect(!model.isBusy)
        #expect(await repository.registeredEmail == nil)
    }
    @Test func authUsesUseCaseAndClearsPasswordsOnSuccess() async {
        let repository = RepositorySpy()
        let model = AuthViewModel(useCases: AuthUseCases(repository: repository, identity: GoogleIdentitySpy()), registration: true)
        model.email = " USER@example.com "; model.password = "password"; model.confirmation = "password"
        await model.submit()
        #expect(await repository.registeredEmail == "user@example.com")
        #expect(model.password.isEmpty && model.confirmation.isEmpty)
        #expect(model.error == nil)
    }
    @Test func listKeepsLoadedValuesOnRefreshFailureAndClearsOnPeriodChange() async {
        let todo = Todo(id: UUID(), title: "Task", dueAt: .now, status: .done)
        let repository = RepositorySpy(values: [todo])
        let model = TodoListViewModel(useCases: TodoUseCases(repository: repository))
        await model.load()
        #expect(model.todos == [todo] && model.completed == 1)
        await repository.setError(.network)
        await model.load()
        #expect(model.todos == [todo])
        #expect(model.error == AppError.network.messageKey)
        model.period = .week
        await model.load()
        #expect(model.todos.isEmpty && !model.hasLoaded && !model.isLoading)
    }
    @Test func editorTracksDirtyDraftAndUsesCreateUseCase() async {
        let repository = RepositorySpy()
        let model = TodoEditorViewModel(todo: nil, useCases: TodoUseCases(repository: repository))
        #expect(!model.isDirty)
        model.draft.title = "  New task  "
        #expect(model.isDirty)
        guard case .saved(let created) = await model.save() else { Issue.record("expected a saved change"); return }
        #expect(created.title == "New task")
        #expect(await repository.savedDraft?.title == "New task")
    }
    @Test func editorRefusesInvalidSaveAndPreservesDraftOnFailure() async {
        let repository = RepositorySpy(error: .network)
        let model = TodoEditorViewModel(todo: nil, useCases: TodoUseCases(repository: repository))
        #expect(await model.save() == nil)
        #expect(model.titleError == ValidationIssue.titleBlank.messageKey)
        #expect(await repository.writeCount == 0)
        model.draft.title = "Keep this draft"
        #expect(await model.save() == nil)
        #expect(model.draft.title == "Keep this draft" && model.error == AppError.network.messageKey)
        #expect(!model.isBusy)
    }
    @Test func editorLoadsUpdatesAndDeletesThroughUseCases() async {
        let todo = Todo(id: UUID(), title: "Task", dueAt: .now)
        let repository = RepositorySpy(values: [todo])
        let model = TodoEditorViewModel(todo: todo, useCases: TodoUseCases(repository: repository))
        await model.load()
        #expect(!model.loadFailed && !model.isDirty)
        model.draft.status = .done
        guard case .saved(let updated) = await model.save() else { Issue.record("expected a saved change"); return }
        #expect(updated.id == todo.id && updated.status == .done)
        #expect(await repository.savedDraft?.status == .done)
        #expect(await model.delete() == .deleted(id: todo.id))
        #expect(await repository.deletedID == todo.id)
    }
    @Test func editorShowsListCopyAndRefreshesWithoutDiscardingEdits() async {
        let listed = Todo(id: UUID(), title: "Listed", dueAt: .now)
        let repository = RepositorySpy(values: [Todo(id: listed.id, title: "Fresh", dueAt: listed.dueAt)])
        let model = TodoEditorViewModel(todo: listed, useCases: TodoUseCases(repository: repository))
        #expect(model.draft.title == "Listed")
        await model.load()
        #expect(model.draft.title == "Fresh" && !model.isDirty)
        model.draft.title = "Typed while refreshing"
        await model.load()
        #expect(model.draft.title == "Typed while refreshing" && model.isDirty)
    }
    @Test func editorRefreshFailureKeepsFormUsable() async {
        let todo = Todo(id: UUID(), title: "Task", dueAt: .now)
        let repository = RepositorySpy(values: [todo], error: .network)
        let model = TodoEditorViewModel(todo: todo, useCases: TodoUseCases(repository: repository))
        await model.load()
        #expect(!model.loadFailed && model.error == nil && model.draft.title == "Task")
        await repository.setError(nil)
        #expect(await model.save() != nil)
    }
    @Test func editorBlocksEditingDeletedTask() async {
        let todo = Todo(id: UUID(), title: "Task", dueAt: .now)
        let repository = RepositorySpy()
        let model = TodoEditorViewModel(todo: todo, useCases: TodoUseCases(repository: repository))
        await model.load()
        #expect(model.loadFailed && model.error == AppError.notFound.messageKey)
        #expect(await model.save() == nil)
        #expect(await repository.writeCount == 0)
    }
    @Test func listAppliesEditorResultWithoutReloading() async {
        let existing = Todo(id: UUID(), title: "Existing", dueAt: .now)
        let repository = RepositorySpy(values: [existing])
        let useCases = TodoUseCases(repository: repository)
        let model = TodoListViewModel(useCases: useCases)
        await model.load()
        let editor = TodoEditorViewModel(todo: nil, useCases: useCases)
        editor.draft.title = "Created"
        editor.draft.dueAt = existing.dueAt.addingTimeInterval(-1)
        guard let change = await editor.save() else { Issue.record("expected a saved change"); return }
        model.apply(change)
        #expect(model.todos.map(\.title) == ["Created", "Existing"])
        model.apply(.deleted(id: existing.id))
        #expect(model.todos.map(\.title) == ["Created"])
        #expect(await repository.listCalls == 1)
    }
    @Test func sessionExplainsInvoluntarySignOut() async {
        let repository = RepositorySpy(states: [.signedIn, .expired])
        let model = SessionViewModel(auth: AuthUseCases(repository: repository, identity: GoogleIdentitySpy()),
                                     todos: TodoUseCases(repository: repository))
        await model.observe()
        #expect(model.phase == .signedOut)
        #expect(model.error == AppError.sessionExpired.messageKey)
    }
    @Test func voluntarySignOutShowsNoNotice() async {
        let repository = RepositorySpy(states: [.signedIn, .signedOut])
        let model = SessionViewModel(auth: AuthUseCases(repository: repository, identity: GoogleIdentitySpy()),
                                     todos: TodoUseCases(repository: repository))
        await model.observe()
        #expect(model.phase == .signedOut && model.error == nil)
    }
    @Test func translationsShipWithThePackage() {
        let ru = presentationBundle.url(forResource: "ru", withExtension: "lproj").flatMap(Bundle.init(url:))
        #expect(ru?.localizedString(forKey: "Discard changes?", value: nil, table: nil) == "Отменить изменения?")
        #expect(ru?.localizedString(forKey: AppError.sessionExpired.messageKey, value: nil, table: nil) == "Сессия истекла. Войдите снова.")
    }
    @Test func sessionObservesAndLoadsProfileWithoutDataDependency() async {
        let repository = RepositorySpy()
        let model = SessionViewModel(auth: AuthUseCases(repository: repository, identity: GoogleIdentitySpy()),
                                     todos: TodoUseCases(repository: repository))
        await model.observe()
        #expect(model.phase == .signedIn)
        await model.loadUser()
        #expect(model.user?.email == "person@example.com")
    }
}
