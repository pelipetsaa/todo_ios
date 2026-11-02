#if os(iOS)
import SwiftUI
import TodoDomain
import TodoApplication

struct TodoEditorView: View {
    @State private var model: TodoEditorViewModel
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?
    private enum Field { case title, description }
    private let onChange: (TodoChange) -> Void

    init(todo: Todo?, useCases: TodoUseCases, onChange: @escaping (TodoChange) -> Void) {
        _model = State(initialValue: TodoEditorViewModel(todo: todo, useCases: useCases))
        self.onChange = onChange
    }

    private func finish(_ change: TodoChange?) {
        guard let change else { return }
        onChange(change)
        dismiss()
    }

    var body: some View {
        Group {
            if model.loadFailed {
                ContentUnavailableView {
                    Label(localized("Unable to load task"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(localized(model.error ?? AppError.server.messageKey))
                } actions: { Button(localized("Retry")) { Task { await model.load() } } }
            } else { form }
        }
        .background(Color(.systemBackground))
        .navigationTitle(model.id == nil ? localized("New todo") : localized("Edit todo"))
        .navigationBarTitleDisplayMode(.inline)
        // Hiding the system back button also disables the swipe-back gesture, so edits cannot be lost silently.
        .navigationBarBackButtonHidden(model.isDirty)
        .toolbar {
            if model.isDirty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        focused = nil
                        confirmDiscard = true
                    } label: {
                        Label(localized("Back"), systemImage: "chevron.backward")
                    }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("backButton")
                }
            }
            if model.id != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmDelete = true
                    } label: {
                        Label(localized("Delete"), systemImage: "trash")
                    }
                    .disabled(model.isBusy || model.loadFailed)
                    .accessibilityIdentifier("deleteTask")
                }
            }
        }
        .alert(localized("Delete this todo?"), isPresented: $confirmDelete) {
            Button(localized("Delete"), role: .destructive) { Task { finish(await model.delete()) } }
            Button(localized("Cancel"), role: .cancel) { }
        } message: { Text(localized("This action cannot be undone.")) }
        .confirmationDialog(localized("Discard changes?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(localized("Discard"), role: .destructive) { dismiss() }
            Button(localized("Keep editing"), role: .cancel) { }
        }
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
                        Text(localized("Date")).font(.subheadline)
                        DatePicker(localized("Date"), selection: $model.draft.dueAt, displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.compact)
                            .accessibilityIdentifier("taskDate")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("Time")).font(.subheadline)
                        DatePicker(localized("Time"), selection: $model.draft.dueAt, displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.compact)
                            .accessibilityIdentifier("taskTime")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(localized("Status")).font(.subheadline.weight(.medium))
                Picker(localized("Status"), selection: $model.draft.status) {
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
                    Task { finish(await model.save()) }
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
