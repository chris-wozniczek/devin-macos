import Foundation
import SwiftData
import SwiftUI

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case backlog, todo, inProgress, inReview, done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog: "Backlog"
        case .todo: "Todo"
        case .inProgress: "In Progress"
        case .inReview: "In Review"
        case .done: "Done"
        }
    }

    var symbol: String {
        switch self {
        case .backlog: "circle.dashed"
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .inReview: "eye.circle"
        case .done: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .backlog: .secondary
        case .todo: Color(red: 0.55, green: 0.58, blue: 0.65)
        case .inProgress: Color(red: 0.95, green: 0.68, blue: 0.20)
        case .inReview: Color(red: 0.40, green: 0.55, blue: 0.95)
        case .done: Color(red: 0.35, green: 0.70, blue: 0.45)
        }
    }

    var order: Int { TaskStatus.allCases.firstIndex(of: self) ?? 0 }
}

enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Comparable {
    case none = 0, low, medium, high, urgent

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "No priority"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var symbol: String {
        switch self {
        case .none: "minus"
        case .low: "cellularbars"
        case .medium: "cellularbars"
        case .high: "cellularbars"
        case .urgent: "exclamationmark.2"
        }
    }

    var tint: Color {
        switch self {
        case .none: .secondary
        case .low: Color(red: 0.55, green: 0.58, blue: 0.65)
        case .medium: Color(red: 0.95, green: 0.68, blue: 0.20)
        case .high: Color(red: 0.95, green: 0.45, blue: 0.25)
        case .urgent: Color(red: 0.90, green: 0.25, blue: 0.30)
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum ProjectColor: String, Codable, CaseIterable, Identifiable {
    case indigo, blue, teal, green, yellow, orange, red, pink, purple, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .indigo: Color(red: 0.42, green: 0.36, blue: 0.95)
        case .blue: Color(red: 0.25, green: 0.55, blue: 0.95)
        case .teal: Color(red: 0.20, green: 0.70, blue: 0.70)
        case .green: Color(red: 0.35, green: 0.70, blue: 0.45)
        case .yellow: Color(red: 0.95, green: 0.75, blue: 0.20)
        case .orange: Color(red: 0.95, green: 0.55, blue: 0.25)
        case .red: Color(red: 0.90, green: 0.30, blue: 0.30)
        case .pink: Color(red: 0.92, green: 0.40, blue: 0.65)
        case .purple: Color(red: 0.65, green: 0.40, blue: 0.90)
        case .gray: Color(red: 0.55, green: 0.58, blue: 0.65)
        }
    }
}

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var summary: String = ""
    var key: String = ""
    var colorName: String = ProjectColor.indigo.rawValue
    var icon: String = "folder.fill"
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var nextTaskNumber: Int = 1

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.project)
    var tasks: [TaskItem]? = []

    init(name: String, key: String? = nil, summary: String = "", color: ProjectColor = .indigo, icon: String = "folder.fill", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.key = key ?? Project.makeKey(from: name)
        self.summary = summary
        self.colorName = color.rawValue
        self.icon = icon
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.nextTaskNumber = 1
    }

    var color: ProjectColor {
        get { ProjectColor(rawValue: colorName) ?? .indigo }
        set { colorName = newValue.rawValue }
    }

    var topLevelTasks: [TaskItem] { (tasks ?? []).filter { $0.parent == nil } }

    var progress: Double {
        let all = topLevelTasks
        guard !all.isEmpty else { return 0 }
        return Double(all.filter { $0.status == .done }.count) / Double(all.count)
    }

    func claimTaskNumber() -> Int {
        defer { nextTaskNumber += 1 }
        return nextTaskNumber
    }

    static func makeKey(from name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        let initials = words.prefix(3).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        if initials.count >= 2 { return initials }
        return String(name.uppercased().filter(\.isLetter).prefix(3)).padding(toLength: max(2, min(3, name.count)), withPad: "X", startingAt: 0)
    }
}

@Model
final class TaskItem {
    var id: UUID = UUID()
    var number: Int = 0
    var title: String = ""
    var details: String = ""
    var statusRaw: String = TaskStatus.todo.rawValue
    var priorityRaw: Int = TaskPriority.none.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dueDate: Date?
    var sortOrder: Double = 0
    var labels: [String] = []

    var project: Project?
    var parent: TaskItem?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var subtasks: [TaskItem]? = []

    init(title: String, project: Project, status: TaskStatus = .todo, priority: TaskPriority = .none, parent: TaskItem? = nil, sortOrder: Double = 0) {
        self.id = UUID()
        self.title = title
        self.project = project
        self.number = project.claimTaskNumber()
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.parent = parent
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue; updatedAt = Date() }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue; updatedAt = Date() }
    }

    var identifier: String { "\(project?.key ?? "TASK")-\(number)" }

    var sortedSubtasks: [TaskItem] { (subtasks ?? []).sorted { $0.sortOrder < $1.sortOrder } }

    var completedSubtaskCount: Int { (subtasks ?? []).filter { $0.status == .done }.count }

    var isOverdue: Bool {
        guard let dueDate, status != .done else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }
}
