import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var newSubtask = ""
    @State private var newLabel = ""
    @State private var confirmDelete = false
    @FocusState private var subtaskFieldFocused: Bool

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { task.dueDate != nil },
            set: { on in task.dueDate = on ? (task.dueDate ?? Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))) : nil }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    titleSection
                    propertiesSection
                    descriptionSection
                    subtasksSection
                    metaSection
                }
                .padding(24)
            }
            .background(Theme.boardBackground)
            .navigationTitle(task.identifier)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog("Delete \(task.identifier)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Task", role: .destructive) {
                    context.delete(task)
                    dismiss()
                }
            } message: {
                Text("This also deletes its \(task.subtasks?.count ?? 0) subtasks.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 560, idealHeight: 720)
        #else
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let parent = task.parent {
                Label("Subtask of \(parent.identifier) · \(parent.title)", systemImage: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            TextField("Task title", text: $task.title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .onChange(of: task.title) { _, _ in task.updatedAt = Date() }
        }
    }

    private var propertiesSection: some View {
        VStack(spacing: 0) {
            propertyRow("Status", icon: task.status.symbol, tint: task.status.tint) {
                Picker("Status", selection: Binding(get: { task.status }, set: { task.status = $0 })) {
                    ForEach(TaskStatus.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
            Divider().padding(.leading, 36)
            propertyRow("Priority", icon: "flag", tint: task.priority.tint) {
                Picker("Priority", selection: Binding(get: { task.priority }, set: { task.priority = $0 })) {
                    ForEach(TaskPriority.allCases.reversed()) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
            Divider().padding(.leading, 36)
            propertyRow("Due date", icon: "calendar", tint: task.isOverdue ? .red : .secondary) {
                HStack(spacing: 10) {
                    if task.dueDate != nil {
                        DatePicker("Due", selection: Binding(get: { task.dueDate ?? Date() }, set: { task.dueDate = $0 }), displayedComponents: .date)
                            .labelsHidden()
                    }
                    Toggle("", isOn: hasDueDate.animation(.snappy)).labelsHidden()
                }
            }
            Divider().padding(.leading, 36)
            propertyRow("Labels", icon: "tag", tint: .secondary) {
                labelsEditor
            }
        }
        .card()
    }

    private func propertyRow<Content: View>(_ title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Spacer()
            content()
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }

    private var labelsEditor: some View {
        HStack(spacing: 6) {
            ForEach(task.labels, id: \.self) { label in
                LabelChip(text: label)
                    .contextMenu {
                        Button("Remove", role: .destructive) { task.labels.removeAll { $0 == label } }
                    }
            }
            TextField("Add", text: $newLabel)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .font(.caption)
                .frame(width: 70)
                .onSubmit(addLabel)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Description")
            TextEditor(text: $task.details)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .overlay(alignment: .topLeading) {
                    if task.details.isEmpty {
                        Text("Add a description...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .card()
        }
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Subtasks")
                Spacer()
                if let subs = task.subtasks, !subs.isEmpty {
                    Text("\(task.completedSubtaskCount) of \(subs.count) done")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 0) {
                if let subs = task.subtasks, !subs.isEmpty {
                    ProgressView(value: Double(task.completedSubtaskCount), total: Double(subs.count))
                        .tint(TaskStatus.done.tint)
                        .padding(.bottom, 8)
                }
                ForEach(task.sortedSubtasks) { sub in
                    SubtaskRow(subtask: sub)
                    Divider().padding(.leading, 28)
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                    TextField("Add a subtask", text: $newSubtask)
                        .textFieldStyle(.plain)
                        .focused($subtaskFieldFocused)
                        .onSubmit(addSubtask)
                }
                .padding(.vertical, 8)
            }
            .card()
        }
    }

    private var metaSection: some View {
        HStack {
            Text("Created \(task.createdAt.formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            Text("Updated \(task.updatedAt.formatted(.relative(presentation: .named)))")
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .kerning(0.6)
    }

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let project = task.project else { return }
        let order = (task.subtasks?.map(\.sortOrder).max() ?? 0) + 1
        let sub = TaskItem(title: title, project: project, status: .todo, parent: task, sortOrder: order)
        context.insert(sub)
        newSubtask = ""
        subtaskFieldFocused = true
    }

    private func addLabel() {
        let label = newLabel.trimmingCharacters(in: .whitespaces).lowercased()
        guard !label.isEmpty, !task.labels.contains(label) else { newLabel = ""; return }
        task.labels.append(label)
        newLabel = ""
    }
}

private struct SubtaskRow: View {
    @Bindable var subtask: TaskItem
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) { subtask.status = subtask.status == .done ? .todo : .done }
            } label: {
                Image(systemName: subtask.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(subtask.status == .done ? TaskStatus.done.tint : .secondary)
            }
            .buttonStyle(.plain)
            TextField("Subtask", text: $subtask.title)
                .textFieldStyle(.plain)
                .strikethrough(subtask.status == .done, color: .secondary)
                .foregroundStyle(subtask.status == .done ? .secondary : .primary)
            Spacer()
            Button(role: .destructive) {
                withAnimation(.snappy) { context.delete(subtask) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
    }
}
