import Foundation
import SwiftData

enum SampleData {
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Project>())) ?? 0
        guard count == 0 else { return }

        let mobile = Project(name: "Mobile App", key: "MOB", summary: "iOS client for the new platform launch.", color: .indigo, icon: "iphone", sortOrder: 0)
        let web = Project(name: "Website Redesign", key: "WEB", summary: "Marketing site refresh for Q4.", color: .teal, icon: "globe", sortOrder: 1)
        let ops = Project(name: "Infrastructure", key: "OPS", summary: "Platform reliability and tooling.", color: .orange, icon: "server.rack", sortOrder: 2)
        [mobile, web, ops].forEach(context.insert)

        var order: Double = 0
        func add(_ title: String, to project: Project, status: TaskStatus, priority: TaskPriority, details: String = "", labels: [String] = [], due: Int? = nil, subtasks: [(String, Bool)] = []) {
            order += 1
            let task = TaskItem(title: title, project: project, status: status, priority: priority, sortOrder: order)
            task.details = details
            task.labels = labels
            if let due { task.dueDate = Calendar.current.date(byAdding: .day, value: due, to: Date()) }
            context.insert(task)
            for (index, sub) in subtasks.enumerated() {
                let child = TaskItem(title: sub.0, project: project, status: sub.1 ? .done : .todo, parent: task, sortOrder: Double(index))
                context.insert(child)
            }
        }

        add("Onboarding flow redesign", to: mobile, status: .inProgress, priority: .high,
            details: "Reduce the number of steps from 6 to 3 and add a progress indicator. Sign-in with Apple should be the primary CTA.",
            labels: ["design", "ios"], due: 3,
            subtasks: [("Wireframes", true), ("Sign in with Apple", true), ("Progress indicator", false), ("Analytics events", false)])
        add("Crash on launch when offline", to: mobile, status: .todo, priority: .urgent,
            details: "Network reachability check throws before the cache is warmed. Repro: enable airplane mode, cold launch.",
            labels: ["bug"], due: 1)
        add("Push notification preferences", to: mobile, status: .backlog, priority: .medium, labels: ["ios"])
        add("Dark mode audit", to: mobile, status: .inReview, priority: .low, labels: ["design"],
            subtasks: [("Settings screens", true), ("Charts", true), ("Empty states", true)])
        add("Widget for today's tasks", to: mobile, status: .backlog, priority: .medium, labels: ["ios", "widgets"])
        add("App Store screenshots", to: mobile, status: .done, priority: .medium, labels: ["marketing"])
        add("Migrate to SwiftData", to: mobile, status: .done, priority: .high, labels: ["tech-debt"])

        add("New landing page hero", to: web, status: .inProgress, priority: .high, labels: ["design"], due: 5,
            subtasks: [("Copywriting", true), ("Hero animation", false)])
        add("Pricing page A/B test", to: web, status: .todo, priority: .medium, labels: ["growth"], due: 10)
        add("Blog CMS integration", to: web, status: .backlog, priority: .low)
        add("Lighthouse score above 95", to: web, status: .inReview, priority: .medium, labels: ["performance"])
        add("Cookie consent banner", to: web, status: .done, priority: .low, labels: ["legal"])

        add("Set up staging cluster", to: ops, status: .inProgress, priority: .urgent, labels: ["k8s"], due: 2,
            subtasks: [("Terraform module", true), ("Ingress + TLS", false), ("Secrets sync", false)])
        add("Rotate database credentials", to: ops, status: .todo, priority: .high, labels: ["security"], due: -1)
        add("Alerting for p95 latency", to: ops, status: .backlog, priority: .medium, labels: ["observability"])
        add("Upgrade Postgres to 16", to: ops, status: .done, priority: .medium)

        try? context.save()
    }
}
