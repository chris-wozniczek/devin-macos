import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @State private var selectedProjectID: UUID?
    @State private var editingProject: Project?
    @State private var creatingProject = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var selectedProject: Project? {
        projects.first { $0.id == selectedProjectID } ?? projects.first
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if let project = selectedProject {
                ProjectView(project: project)
                    .id(project.id)
            } else {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "square.grid.2x2")
                } description: {
                    Text("Create a project to start tracking work.")
                } actions: {
                    Button("New Project") { creatingProject = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $creatingProject) {
            ProjectEditorView(project: nil) { project in
                selectedProjectID = project.id
            }
        }
        .sheet(item: $editingProject) { project in
            ProjectEditorView(project: project, onSave: { _ in })
        }
        .onAppear { if selectedProjectID == nil { selectedProjectID = projects.first?.id } }
        .tint(Theme.accent)
    }

    private var sidebar: some View {
        List(selection: $selectedProjectID) {
            Section {
                ForEach(projects) { project in
                    ProjectRow(project: project)
                        .tag(project.id)
                        .contextMenu {
                            Button("Edit Project", systemImage: "pencil") { editingProject = project }
                            Divider()
                            Button("Delete Project", systemImage: "trash", role: .destructive) { delete(project) }
                        }
                }
                .onMove(perform: move)
            } header: {
                HStack {
                    Text("Projects")
                    Spacer()
                    Button { creatingProject = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("New Project")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Boards")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creatingProject = true } label: { Image(systemName: "plus") }
            }
        }
        #endif
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = projects
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in reordered.enumerated() { project.sortOrder = index }
    }

    private func delete(_ project: Project) {
        if selectedProjectID == project.id { selectedProjectID = projects.first { $0.id != project.id }?.id }
        context.delete(project)
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: project.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(project.color.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                Text("\(project.topLevelTasks.filter { $0.status != .done }.count) open")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(progress: project.progress, tint: project.color.color)
                .frame(width: 16, height: 16)
        }
        .padding(.vertical, 2)
    }
}

struct ProgressRing: View {
    let progress: Double
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
        }
    }
}
