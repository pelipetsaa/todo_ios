import Foundation
import Observation
import TodoDomain
import TodoApplication

@MainActor @Observable
final class TodoEditorViewModel {
    var draft: TodoDraft
    private(set) var isBusy = false
    private(set) var loadFailed = false
    private(set) var submitted = false
    var error: String?
    private var original: TodoDraft
    let id: Todo.ID?
    private let useCases: TodoUseCases

    init(todo: Todo?, useCases: TodoUseCases) {
        id = todo?.id
        let draft = todo.map(TodoDraft.init) ?? useCases.newDraft()
        self.draft = draft
        original = draft
        self.useCases = useCases
    }
    var isDirty: Bool { draft != original }
    var titleError: String? { submitted ? Validation.title(draft.title)?.messageKey : nil }
    var descriptionError: String? { submitted ? Validation.description(draft.description)?.messageKey : nil }

    /// The list already supplied the task, so the form stays usable while a fresher copy is fetched in the background.
    func load() async {
        guard let id else { return }
        loadFailed = false
        error = nil
        do {
            let fresh = TodoDraft(todo: try await useCases.detail(id: id))
            try Task.checkCancellation()
            // Never discard edits made while the refresh was in flight.
            if !isDirty { draft = fresh; original = fresh }
        } catch is CancellationError { }
        catch AppError.notFound { loadFailed = true; self.error = AppError.notFound.messageKey }
        catch { /* Keep the list's copy; save and delete report connectivity problems themselves. */ }
    }

    /// Returns the change for the list to apply, or nil when nothing was saved.
    func save() async -> TodoChange? {
        guard !isBusy, !loadFailed else { return nil }
        submitted = true
        error = nil
        guard titleError == nil, descriptionError == nil else { return nil }
        isBusy = true
        defer { isBusy = false }
        do {
            let saved: Todo
            if let id { saved = try await useCases.update(id: id, draft: draft) }
            else { saved = try await useCases.create(draft) }
            return .saved(saved)
        } catch is CancellationError { return nil }
        catch { self.error = errorKey(error); return nil }
    }

    func delete() async -> TodoChange? {
        guard let id, !isBusy else { return nil }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do { try await useCases.delete(id: id); return .deleted(id: id) }
        catch is CancellationError { return nil }
        catch { self.error = errorKey(error); return nil }
    }
}
