#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

private struct EditorRoute: Identifiable {
    let id = UUID()
    let todo: Todo?
}

struct TodoListView: View {
    @State private var model: TodoListViewModel
    @State private var editor: EditorRoute?
    @State private var confirmSignOut = false
    @Environment(\.scenePhase) private var scenePhase
    private let session: SessionViewModel

    init(session: SessionViewModel) {
        self.session = session
        _model = State(initialValue: TodoListViewModel(useCases: session.todos))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heading
                Picker("Period", selection: $model.period) {
                    ForEach(TodoPeriod.allCases) { period in Text(localized(period.titleKey)).tag(period) }
                }.pickerStyle(.segmented).accessibilityIdentifier("periodPicker")
                if let error = model.error {
                    VStack(spacing: 10) {
                        ErrorNotice(message: error)
                        Button("Try again") { Task { await model.load() } }.buttonStyle(.bordered)
                    }
                }
                if model.isLoading && !model.hasLoaded {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 220).accessibilityLabel("Loading tasks")
                } else if model.hasLoaded && model.todos.isEmpty {
                    ContentUnavailableView {
                        Label("A little breathing room", systemImage: "checklist")
                    } description: {
                        Text("No tasks in this period. Add something you want to get done.")
                    } actions: {
                        Button("Add a task") { editor = EditorRoute(todo: nil) }
                            .buttonStyle(.borderedProminent)
                    }.padding(.top, 32)
                } else {
                    taskList
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await model.load() }
        .navigationTitle("My tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let email = session.user?.email { Text(email) }
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        confirmSignOut = true
                    }.disabled(session.isSigningOut)
                } label: {
                    Image(systemName: "person.crop.circle").font(.title3)
                }.accessibilityLabel("Account").accessibilityIdentifier("accountMenu")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    editor = EditorRoute(todo: nil)
                } label: {
                    Label("New task", systemImage: "plus").font(.headline).padding(.vertical, 8).padding(.horizontal, 10)
                }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .shadow(color: .indigo.opacity(0.18), radius: 12, y: 6)
                    .accessibilityIdentifier("addTask")
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .task(id: model.period) { await model.load() }
        .task { await session.loadUser() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
        .sheet(item: $editor, onDismiss: { Task { await model.load() } }) { route in
            NavigationStack { TodoEditorView(todo: route.todo, useCases: session.todos) }
        }
        .confirmationDialog("Sign out of your account?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await session.signOut() } }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var heading: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Text("One thing at a time.")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                if model.hasLoaded {
                    Text("\(model.completed) of \(model.todos.count) completed")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("completionCount")
                }
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.indigo.opacity(0.10), lineWidth: 7)
                Circle().trim(from: 0, to: model.todos.isEmpty ? 0 : Double(model.completed) / Double(model.todos.count))
                    .stroke(.indigo, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark").font(.title3.weight(.bold)).foregroundStyle(.indigo)
            }.frame(width: 54, height: 54).accessibilityHidden(true)
        }.padding(.vertical, 10)
    }

    private var taskList: some View {
        LazyVStack(spacing: 12) {
            ForEach(model.todos) { todo in
                Button { editor = EditorRoute(todo: todo) } label: { TodoRow(todo: todo) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("todoRow-\(todo.id)")
            }
        }
    }
}

private struct TodoRow: View {
    let todo: Todo
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3).fill(todo.status.color).frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(todo.dueAt, style: .time).font(.subheadline.weight(.semibold)).foregroundStyle(.indigo)
                    Text(todo.dueAt, format: .dateTime.day().month(.abbreviated))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                }
                Text(todo.title).font(.headline).foregroundStyle(.primary).lineLimit(3)
                    .strikethrough(todo.status == .done, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !todo.description.isEmpty {
                    Text(todo.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                StatusBadge(status: todo.status)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

#endif
