#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

private struct EditorRoute: Identifiable, Hashable {
    let id = UUID()
    let todo: Todo?
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TodoListView: View {
    @State private var model: TodoListViewModel
    @State private var editor: EditorRoute?
    @Environment(\.scenePhase) private var scenePhase
    private let session: SessionViewModel

    init(session: SessionViewModel) {
        self.session = session
        _model = State(initialValue: TodoListViewModel(useCases: session.todos))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Period", selection: $model.period) {
                ForEach(TodoPeriod.allCases) { period in Text(localized(period.titleKey)).tag(period) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .accessibilityIdentifier("periodPicker")
            Divider()
            List(model.todos) { todo in
                Button { editor = EditorRoute(todo: todo) } label: { TodoRow(todo: todo) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("todoRow-\(todo.id)")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            .listStyle(.plain)
            .safeAreaPadding(.bottom, 88)
            .refreshable { await model.load() }
            .overlay {
                if model.isLoading && !model.hasLoaded {
                    ProgressView().accessibilityLabel("Loading tasks")
                } else if let error = model.error, !model.hasLoaded {
                    ListPlaceholder(title: error, retry: { Task { await model.load() } })
                } else if model.hasLoaded && model.todos.isEmpty {
                    ListPlaceholder(title: model.period.emptyTitleKey, subtitle: "Tap + to add a todo")
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("My todos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await session.signOut() }
                } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(session.isSigningOut)
                .accessibilityIdentifier("logoutButton")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button { editor = EditorRoute(todo: nil) } label: {
                Label("Add todo", systemImage: "plus")
                    .labelStyle(.iconOnly).font(.title2)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.circle)
            .padding(16)
            .accessibilityIdentifier("addTask")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let error = model.error, model.hasLoaded {
                ErrorNotice(message: error).padding(16).background(.regularMaterial)
            }
        }
        .task(id: model.period) { await model.load() }
        .task { await session.loadUser() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
        .navigationDestination(item: $editor) { route in
            TodoEditorView(todo: route.todo, useCases: session.todos)
        }
        .onChange(of: editor?.id) { previous, current in
            if previous != nil && current == nil { Task { await model.load() } }
        }
    }
}

private struct TodoRow: View {
    let todo: Todo
    var body: some View {
        HStack(spacing: 16) {
            Text(timeText).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                // Two lines keep long titles readable next to a wide status badge.
                Text(todo.title).font(.body).foregroundStyle(.primary).lineLimit(2)
                Text(dateText).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            StatusBadge(status: todo.status)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // Format styles are value types cached by Foundation, unlike a DateFormatter built on every render.
    // The time follows the device's 12/24-hour setting; two-digit hours keep the column aligned.
    private var timeText: String {
        todo.dueAt.formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits))
    }
    private var dateText: String {
        let style = Date.VerbatimFormatStyle(
            format: "\(weekday: .abbreviated), \(day: .defaultDigits) \(month: .abbreviated) \(year: .defaultDigits)",
            locale: .current, timeZone: .current, calendar: .current)
        let value = todo.dueAt.formatted(style)
        return value.prefix(1).uppercased() + String(value.dropFirst())
    }
}

private struct ListPlaceholder: View {
    let title: String
    var subtitle: String?
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist").font(.title2).foregroundStyle(.secondary)
                .padding(.top, 64).accessibilityHidden(true)
            Text(localized(title)).font(.headline).multilineTextAlignment(.center)
            if let subtitle { Text(localized(subtitle)).font(.subheadline).foregroundStyle(.secondary) }
            if let retry { Button("Retry", action: retry).buttonStyle(.borderedProminent) }
        }.frame(maxWidth: 360).padding(32)
    }
}
#endif
