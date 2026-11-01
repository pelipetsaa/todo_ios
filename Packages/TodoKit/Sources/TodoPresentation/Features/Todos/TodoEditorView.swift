#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

struct TodoEditorView: View {
    @State private var model: TodoEditorViewModel
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?
    private enum Field { case title, description }

    init(todo: Todo?, useCases: TodoUseCases) {
        _model = State(initialValue: TodoEditorViewModel(todo: todo, useCases: useCases))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.loadFailed {
                ContentUnavailableView {
                    Label("Unable to load task", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(localized(model.error ?? AppError.server.messageKey))
                } actions: { Button("Retry") { Task { await model.load() } } }
            } else { form }
        }
        .background(Color(.systemBackground))
        .navigationTitle(model.id == nil ? localized("New todo") : localized("Edit todo"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.id != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(model.isBusy || model.isLoading || model.loadFailed)
                    .accessibilityIdentifier("deleteTask")
                }
            }
        }
        .alert("Delete this todo?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { if await model.delete() { dismiss() } } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This action cannot be undone.") }
        .task { await model.load() }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InputField(title: "Title", error: model.titleError) {
                    TextField("", text: $model.draft.title)
                        .focused($focused, equals: .title).submitLabel(.next)
                        .onSubmit { focused = .description }
                        .accessibilityIdentifier("taskTitle")
                }
                InputField(title: "Description", error: model.descriptionError) {
                    TextField("", text: $model.draft.description, axis: .vertical)
                        .lineLimit(3...8).focused($focused, equals: .description)
                        .accessibilityIdentifier("taskDescription")
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date").font(.subheadline)
                        DatePicker("Date", selection: $model.draft.dueAt, displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.compact)
                            .accessibilityIdentifier("taskDate")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time").font(.subheadline)
                        DatePicker("Time", selection: $model.draft.dueAt, displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.compact)
                            .accessibilityIdentifier("taskTime")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Status").font(.subheadline.weight(.medium))
                Picker("Status", selection: $model.draft.status) {
                    ForEach(TodoStatus.allCases, id: \.self) { status in
                        Text(localized(status.titleKey)).tag(status)
                            .accessibilityIdentifier("status-\(status.identifier)")
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("statusPicker")
                if let error = model.error { ErrorNotice(message: error) }
                PrimaryButton(title: "Save", busy: model.isBusy) {
                    focused = nil
                    Task { if await model.save() { dismiss() } }
                }
                .padding(.top, 8)
                .accessibilityIdentifier("saveTask")
            }
            .disabled(model.isBusy)
            .frame(maxWidth: 568)
            .padding(16)
            .frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
    }
}
#endif
