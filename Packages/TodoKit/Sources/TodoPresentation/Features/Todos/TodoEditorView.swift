#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

struct TodoEditorView: View {
    @State private var model: TodoEditorViewModel
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @Environment(\.dismiss) private var dismiss

    init(todo: Todo?, useCases: TodoUseCases) {
        _model = State(initialValue: TodoEditorViewModel(todo: todo, useCases: useCases))
    }

    var body: some View {
        Group {
            if model.isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if model.loadFailed {
                ContentUnavailableView {
                    Label("Unable to load task", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(localized(model.error ?? AppError.server.messageKey))
                } actions: { Button("Try again") { Task { await model.load() } } }
            } else { form }
        }
        .navigationTitle(model.id == nil ? localized("New task") : localized("Edit task"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { if model.isDirty { confirmDiscard = true } else { dismiss() } }
                    .disabled(model.isBusy).accessibilityIdentifier("cancelEditor")
            }
            ToolbarItem(placement: .confirmationAction) {
                if model.isBusy { ProgressView() }
                else {
                    Button("Save") { Task { if await model.save() { dismiss() } } }
                        .fontWeight(.semibold).disabled(model.isLoading || model.loadFailed)
                        .accessibilityIdentifier("saveTask")
                }
            }
        }
        .interactiveDismissDisabled(model.isDirty || model.isBusy)
        .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete task", role: .destructive) { Task { if await model.delete() { dismiss() } } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This action cannot be undone.") }
        .confirmationDialog("Discard changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        }
        .task { await model.load() }
    }

    private var form: some View {
        Form {
            Section {
                TextField("What needs to get done?", text: $model.draft.title, axis: .vertical)
                    .font(.title3.weight(.semibold)).lineLimit(1...4)
                    .accessibilityIdentifier("taskTitle")
                FieldError(message: model.titleError)
                TextField("Add a few details (optional)", text: $model.draft.description, axis: .vertical)
                    .lineLimit(4...10).accessibilityIdentifier("taskDescription")
                FieldError(message: model.descriptionError)
            } header: { Text("Task") } footer: {
                Text("Titles can have up to 200 characters; descriptions up to 2,000.")
            }
            Section("Schedule") {
                DatePicker(selection: $model.draft.dueAt, displayedComponents: .date) {
                    Label("Date", systemImage: "calendar")
                }.accessibilityIdentifier("taskDate")
                DatePicker(selection: $model.draft.dueAt, displayedComponents: .hourAndMinute) {
                    Label("Time", systemImage: "clock")
                }.accessibilityIdentifier("taskTime")
            }
            Section("Status") {
                ForEach(TodoStatus.allCases, id: \.self) { status in
                    Button { model.draft.status = status } label: {
                        HStack {
                            Label(localized(status.titleKey), systemImage: status.symbol).foregroundStyle(status.color)
                            Spacer()
                            if model.draft.status == status {
                                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.indigo)
                            }
                        }.contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(model.draft.status == status ? .isSelected : [])
                    .accessibilityIdentifier("status-\(status.identifier)")
                }
            }
            if let error = model.error { Section { ErrorNotice(message: error).listRowInsets(EdgeInsets()) } }
            if model.id != nil {
                Section {
                    Button("Delete task", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("deleteTask")
                }
            }
        }.disabled(model.isBusy)
    }
}

#endif
