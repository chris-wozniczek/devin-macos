import SwiftData
import SwiftUI

struct TaskListView: View {
    let tasks: [TaskItem]
    let onSelect: (TaskItem) -> Void
    let onCompose: (TaskStatus) -> Void

    var body: some View {
        List {
            ForEach(TaskStatus.allCases) { status in
                let rows = tasks.filter { $0.status == status }
                Section {
                    ForEach(rows) { task in
                        TaskRowView(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(task) }
                            .contextMenu { TaskContextMenu(task: task) }
                    }
                    if rows.isEmpty {
                        Text("No tasks")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: status.symbol).foregroundStyle(status.tint)
                        Text(status.title)
                        Text("\(rows.count)").foregroundStyle(.secondary)
                        Spacer()
                        Button { onCompose(status) } label: {
                            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        #else
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
    }
}

struct TaskRowView: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { task.status = task.status == .done ? .todo : .done }
            } label: {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.status == .done ? TaskStatus.done.tint : .secondary)
            }
            .buttonStyle(.plain)

            PriorityIcon(priority: task.priority)

            Text(task.identifier)
                .font(.caption.weight(.medium).monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Text(task.title)
                .lineLimit(1)
                .strikethrough(task.status == .done, color: .secondary)
                .foregroundStyle(task.status == .done ? .secondary : .primary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(task.labels.prefix(2), id: \.self) { LabelChip(text: $0) }
            }
            if let subs = task.subtasks, !subs.isEmpty {
                Label("\(task.completedSubtaskCount)/\(subs.count)", systemImage: "checklist")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let due = task.dueDate {
                Text(due.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}
