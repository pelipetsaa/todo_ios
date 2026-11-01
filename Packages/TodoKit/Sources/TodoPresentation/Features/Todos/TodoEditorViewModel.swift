import Foundation
import Observation
import TodoDomain
import TodoApplication

@MainActor @Observable
final class TodoEditorViewModel {
    var draft: TodoDraft
    private(set) var isBusy = false
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var submitted = false
    var error: String?
    private var original: TodoDraft
    let id: String?
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

    func load() async {
        guard let id else { return }
        isLoading = true
        loadFailed = false
        error = nil
        defer { isLoading = false }
        do {
            let todo = try await useCases.detail(id: id)
            try Task.checkCancellation()
            draft = TodoDraft(todo: todo)
            original = draft
        } catch is CancellationError { }
        catch { loadFailed = true; self.error = errorKey(error) }
    }

    func save() async -> Bool {
        guard !isBusy, !isLoading, !loadFailed else { return false }
        submitted = true
        error = nil
        guard titleError == nil, descriptionError == nil else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            if let id { _ = try await useCases.update(id: id, draft: draft) }
            else { _ = try await useCases.create(draft) }
            return true
        } catch is CancellationError { return false }
        catch { self.error = errorKey(error); return false }
    }

    func delete() async -> Bool {
        guard let id, !isBusy, !isLoading else { return false }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do { try await useCases.delete(id: id); return true }
        catch is CancellationError { return false }
        catch { self.error = errorKey(error); return false }
    }
}
