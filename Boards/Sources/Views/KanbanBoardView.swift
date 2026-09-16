import SwiftData
import SwiftUI

struct KanbanBoardView: View {
    let tasks: [TaskItem]
    let onSelect: (TaskItem) -> Void
    let onCompose: (TaskStatus) -> Void

    @Environment(\.modelContext) private var context
    @State private var draggingID: UUID?
    @State private var hoveredColumn: TaskStatus?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(TaskStatus.allCases) { status in
                    KanbanColumn(
                        status: status,
                        tasks: tasks.filter { $0.status == status },
                        isTargeted: hoveredColumn == status,
                        draggingID: $draggingID,
                        onSelect: onSelect,
                        onCompose: { onCompose(status) },
                        onDrop: { ids, before in move(ids, to: status, before: before) }
                    )
                    .dropDestination(for: String.self) { ids, _ in
                        move(ids, to: status, before: nil)
                    } isTargeted: { targeted in
                        hoveredColumn = targeted ? status : (hoveredColumn == status ? nil : hoveredColumn)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    @discardableResult
    private func move(_ ids: [String], to status: TaskStatus, before target: TaskItem?) -> Bool {
        let moved = ids.compactMap { id in tasks.first { $0.id.uuidString == id } }
        guard !moved.isEmpty else { return false }
        var column = tasks.filter { $0.status == status && !moved.contains($0) }
        let insertIndex = target.flatMap { t in column.firstIndex(of: t) } ?? column.count
        column.insert(contentsOf: moved, at: insertIndex)
        withAnimation(.snappy) {
            for (index, task) in column.enumerated() {
                task.sortOrder = Double(index)
                if task.status != status { task.status = status }
            }
        }
        draggingID = nil
        return true
    }
}

private struct KanbanColumn: View {
    let status: TaskStatus
    let tasks: [TaskItem]
    let isTargeted: Bool
    @Binding var draggingID: UUID?
    let onSelect: (TaskItem) -> Void
    let onCompose: () -> Void
    let onDrop: ([String], TaskItem?) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCardView(task: task)
                            .opacity(draggingID == task.id ? 0.4 : 1)
                            .onTapGesture { onSelect(task) }
                            .draggable(task.id.uuidString) {
                                TaskCardView(task: task)
                                    .frame(width: 260)
                                    .onAppear { draggingID = task.id }
                            }
                            .dropDestination(for: String.self) { ids, _ in
                                onDrop(ids, task)
                            }
                            .contextMenu { TaskContextMenu(task: task) }
                    }
                    Button(action: onCompose) {
                        Label("Add task", systemImage: "plus")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(10)
        .frame(width: 290)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.columnBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isTargeted ? Theme.accent.opacity(0.7) : .clear, lineWidth: 2)
                }
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: status.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.tint)
            Text(status.title)
                .font(.subheadline.weight(.semibold))
            Text("\(tasks.count)")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            Spacer()
            Button(action: onCompose) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Add task to \(status.title)")
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }
}

struct TaskCardView: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(task.identifier)
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                PriorityIcon(priority: task.priority)
            }
            Text(task.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .strikethrough(task.status == .done, color: .secondary)
                .foregroundStyle(task.status == .done ? .secondary : .primary)

            if !task.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.labels.prefix(3), id: \.self) { LabelChip(text: $0) }
                    if task.labels.count > 3 {
                        Text("+\(task.labels.count - 3)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            if task.dueDate != nil || !(task.subtasks ?? []).isEmpty {
                HStack(spacing: 10) {
                    if let due = task.dueDate {
                        Label(due.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                    if let subs = task.subtasks, !subs.isEmpty {
                        Label("\(task.completedSubtaskCount)/\(subs.count)", systemImage: "checklist")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct TaskContextMenu: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu("Status") {
            ForEach(TaskStatus.allCases) { status in
                Button { withAnimation(.snappy) { task.status = status } } label: {
                    Label(status.title, systemImage: status.symbol)
                }
                .disabled(task.status == status)
            }
        }
        Menu("Priority") {
            ForEach(TaskPriority.allCases.reversed()) { priority in
                Button { task.priority = priority } label: {
                    Label(priority.title, systemImage: priority.symbol)
                }
                .disabled(task.priority == priority)
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation(.snappy) { context.delete(task) }
        }
    }
}
