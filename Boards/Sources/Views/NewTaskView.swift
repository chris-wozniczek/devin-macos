import SwiftData
import SwiftUI

struct NewTaskView: View {
    let project: Project
    let nextSortOrder: Double

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var status: TaskStatus
    @State private var priority: TaskPriority = .none
    @State private var dueDate: Date?
    @State private var labels: [String] = []
    @State private var newLabel = ""
    @State private var subtaskTitles: [String] = []
    @State private var newSubtask = ""
    @FocusState private var titleFocused: Bool

    init(project: Project, status: TaskStatus, nextSortOrder: Double) {
        self.project = project
        self.nextSortOrder = nextSortOrder
        _status = State(initialValue: status)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title, axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .focused($titleFocused)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Properties") {
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases.reversed()) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Toggle("Due date", isOn: Binding(
                        get: { dueDate != nil },
                        set: { dueDate = $0 ? Calendar.current.startOfDay(for: Date().addingTimeInterval(7 * 86400)) : nil }
                    ).animation(.snappy))
                    if dueDate != nil {
                        DatePicker("Due", selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: .date)
                    }
                }

                Section("Labels") {
                    if !labels.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(labels, id: \.self) { label in
                                LabelChip(text: label)
                                    .onTapGesture { labels.removeAll { $0 == label } }
                            }
                        }
                    }
                    TextField("Add label and press return", text: $newLabel)
                        .onSubmit {
                            let l = newLabel.trimmingCharacters(in: .whitespaces).lowercased()
                            if !l.isEmpty, !labels.contains(l) { labels.append(l) }
                            newLabel = ""
                        }
                }

                Section("Subtasks") {
                    ForEach(Array(subtaskTitles.enumerated()), id: \.offset) { index, sub in
                        HStack {
                            Image(systemName: "circle").foregroundStyle(.secondary)
                            Text(sub)
                            Spacer()
                            Button { subtaskTitles.remove(at: index) } label: {
                                Image(systemName: "xmark").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField("Add subtask and press return", text: $newSubtask)
                        .onSubmit {
                            let s = newSubtask.trimmingCharacters(in: .whitespaces)
                            if !s.isEmpty { subtaskTitles.append(s) }
                            newSubtask = ""
                        }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Task in \(project.key)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { titleFocused = true }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 520)
        #else
        .presentationDetents([.large])
        #endif
    }

    private func save() {
        let task = TaskItem(
            title: title.trimmingCharacters(in: .whitespaces),
            project: project,
            status: status,
            priority: priority,
            sortOrder: nextSortOrder
        )
        task.details = details
        task.dueDate = dueDate
        task.labels = labels
        context.insert(task)
        for (index, sub) in subtaskTitles.enumerated() {
            context.insert(TaskItem(title: sub, project: project, status: .todo, parent: task, sortOrder: Double(index)))
        }
        dismiss()
    }
}
