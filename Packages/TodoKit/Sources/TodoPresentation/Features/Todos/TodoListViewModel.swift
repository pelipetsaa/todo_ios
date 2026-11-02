import Foundation
import Observation
import TodoDomain
import TodoApplication

@MainActor @Observable
final class TodoListViewModel {
    var period: TodoPeriod = .today
    private(set) var todos: [Todo] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var error: String?
    private let useCases: TodoUseCases
    private var loadID = UUID()
    private var displayedPeriod: TodoPeriod = .today

    init(useCases: TodoUseCases) { self.useCases = useCases }
    var completed: Int { todos.filter { $0.status == .done }.count }

    func load() async {
        let id = UUID()
        loadID = id
        let requestedPeriod = period
        if displayedPeriod != requestedPeriod {
            todos = []
            hasLoaded = false
            displayedPeriod = requestedPeriod
        }
        isLoading = true
        error = nil
        defer { if loadID == id { isLoading = false } }
        do {
            let values = try await useCases.list(period: requestedPeriod)
            try Task.checkCancellation()
            guard loadID == id, requestedPeriod == period else { return }
            todos = values
            hasLoaded = true
        } catch is CancellationError { }
        catch { if loadID == id { self.error = errorKey(error) } }
    }

    /// Applies the editor's result locally instead of reloading the whole period.
    func apply(_ change: TodoChange) {
        guard hasLoaded else { return }
        todos = useCases.list.applying(change, to: todos, period: displayedPeriod)
    }

}
