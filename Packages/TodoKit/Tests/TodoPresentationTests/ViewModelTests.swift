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
        let todo = Todo(id: "id", title: "Task", dueAt: .now, status: .done)
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
        #expect(await model.save())
        #expect(await repository.savedDraft?.title == "New task")
    }
    @Test func editorRefusesInvalidSaveAndPreservesDraftOnFailure() async {
        let repository = RepositorySpy(error: .network)
        let model = TodoEditorViewModel(todo: nil, useCases: TodoUseCases(repository: repository))
        #expect(await model.save() == false)
        #expect(model.titleError == ValidationIssue.titleBlank.messageKey)
        #expect(await repository.writeCount == 0)
        model.draft.title = "Keep this draft"
        #expect(await model.save() == false)
        #expect(model.draft.title == "Keep this draft" && model.error == AppError.network.messageKey)
        #expect(!model.isBusy)
    }
    @Test func editorLoadsUpdatesAndDeletesThroughUseCases() async {
        let todo = Todo(id: "id", title: "Task", dueAt: .now)
        let repository = RepositorySpy(values: [todo])
        let model = TodoEditorViewModel(todo: todo, useCases: TodoUseCases(repository: repository))
        await model.load()
        #expect(!model.loadFailed && !model.isDirty)
        model.draft.status = .done
        #expect(await model.save())
        #expect(await repository.savedDraft?.status == .done)
        #expect(await model.delete())
        #expect(await repository.deletedID == "id")
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
