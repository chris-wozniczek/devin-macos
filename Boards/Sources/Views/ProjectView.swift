import SwiftData
import SwiftUI

enum ViewMode: String, CaseIterable, Identifiable {
    case board, list
    var id: String { rawValue }
    var title: String { self == .board ? "Board" : "List" }
    var symbol: String { self == .board ? "rectangle.split.3x1" : "list.bullet" }
}

struct ProjectView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]

    @State private var mode: ViewMode = .board
    @State private var searchText = ""
    @State private var priorityFilter: TaskPriority?
    @State private var labelFilter: String?
    @State private var hideDone = false
    @State private var selectedTask: TaskItem?
    @State private var composing: TaskStatus?
    @State private var editingProject = false

    init(project: Project) {
        self.project = project
        let projectID = project.id
        _allTasks = Query(filter: #Predicate<TaskItem> { $0.project?.id == projectID && $0.parent == nil },
                          sort: \TaskItem.sortOrder)
    }

    private var tasks: [TaskItem] {
        allTasks.filter { task in
            if hideDone && task.status == .done { return false }
            if let priorityFilter, task.priority != priorityFilter { return false }
            if let labelFilter, !task.labels.contains(labelFilter) { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return task.title.lowercased().contains(q) || task.identifier.lowercased().contains(q) || task.labels.contains { $0.lowercased().contains(q) }
            }
            return true
        }
    }

    private var allLabels: [String] { Array(Set(allTasks.flatMap(\.labels))).sorted() }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch mode {
                case .board:
                    KanbanBoardView(tasks: tasks, onSelect: { selectedTask = $0 }, onCompose: { composing = $0 })
                case .list:
                    TaskListView(tasks: tasks, onSelect: { selectedTask = $0 }, onCompose: { composing = $0 })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.boardBackground)
        .navigationTitle(project.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search tasks")
        .toolbar { toolbarContent }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(item: $composing) { status in
            NewTaskView(project: project, status: status, nextSortOrder: nextSortOrder(in: status))
        }
        .sheet(isPresented: $editingProject) {
            ProjectEditorView(project: project, onSave: { _ in })
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                identity
                Spacer()
                stats
                settingsButton
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    identity
                    Spacer()
                    settingsButton
                }
                stats
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: project.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(project.color.color))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(project.name).font(.title2.weight(.semibold)).lineLimit(1)
                    Text(project.key)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
                if !project.summary.isEmpty {
                    Text(project.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 14) {
            statChip(value: "\(allTasks.filter { $0.status != .done }.count)", label: "Open")
            statChip(value: "\(allTasks.filter { $0.status == .inProgress }.count)", label: "Active")
            statChip(value: "\(Int(project.progress * 100))%", label: "Done")
        }
    }

    private var settingsButton: some View {
        Button { editingProject = true } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Project settings")
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minWidth: 40)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("View", selection: $mode.animation(.snappy)) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 110)

            Menu {
                Picker("Priority", selection: $priorityFilter) {
                    Text("Any priority").tag(TaskPriority?.none)
                    ForEach(TaskPriority.allCases.reversed()) { p in
                        Label(p.title, systemImage: p.symbol).tag(TaskPriority?.some(p))
                    }
                }
                if !allLabels.isEmpty {
                    Picker("Label", selection: $labelFilter) {
                        Text("Any label").tag(String?.none)
                        ForEach(allLabels, id: \.self) { label in
                            Text(label).tag(String?.some(label))
                        }
                    }
                }
                Toggle("Hide completed", isOn: $hideDone)
                if priorityFilter != nil || labelFilter != nil || hideDone {
                    Divider()
                    Button("Clear filters") { priorityFilter = nil; labelFilter = nil; hideDone = false }
                }
            } label: {
                Label("Filter", systemImage: priorityFilter != nil || labelFilter != nil || hideDone
                      ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }

            Button { composing = .todo } label: {
                Label("New Task", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("New task (⌘N)")
        }
    }

    private func nextSortOrder(in status: TaskStatus) -> Double {
        (allTasks.filter { $0.status == status }.map(\.sortOrder).max() ?? 0) + 1
    }
}
