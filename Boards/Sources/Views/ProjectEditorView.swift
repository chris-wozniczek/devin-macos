import SwiftData
import SwiftUI

struct ProjectEditorView: View {
    let project: Project?
    let onSave: (Project) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    @State private var name: String
    @State private var key: String
    @State private var summary: String
    @State private var color: ProjectColor
    @State private var icon: String
    @State private var keyEdited = false
    @FocusState private var nameFocused: Bool

    private static let icons = [
        "folder.fill", "iphone", "globe", "server.rack", "paintbrush.fill", "hammer.fill",
        "cart.fill", "megaphone.fill", "chart.bar.fill", "lock.fill", "book.fill", "bolt.fill",
        "star.fill", "flame.fill", "leaf.fill", "gamecontroller.fill", "creditcard.fill", "cpu",
    ]

    init(project: Project?, onSave: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project?.name ?? "")
        _key = State(initialValue: project?.key ?? "")
        _summary = State(initialValue: project?.summary ?? "")
        _color = State(initialValue: project?.color ?? .indigo)
        _icon = State(initialValue: project?.icon ?? "folder.fill")
        _keyEdited = State(initialValue: project != nil)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && key.count >= 2 && key.count <= 5
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(color.color.gradient)
                                .frame(width: 56, height: 56)
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Project name", text: $name)
                                .font(.title3.weight(.semibold))
                                .focused($nameFocused)
                                .onChange(of: name) { _, new in
                                    if !keyEdited { key = Project.makeKey(from: new) }
                                }
                            TextField("Summary", text: $summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        Text("Key")
                        Spacer()
                        TextField("KEY", text: $key)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospaced())
                            .textCase(.uppercase)
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                            .frame(maxWidth: 100)
                            .onChange(of: key) { _, new in
                                keyEdited = true
                                let cleaned = String(new.uppercased().filter(\.isLetter).prefix(5))
                                if cleaned != new { key = cleaned }
                            }
                    }
                } footer: {
                    Text("Tasks are numbered \(key.isEmpty ? "KEY" : key)-1, \(key.isEmpty ? "KEY" : key)-2, …")
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 10) {
                        ForEach(ProjectColor.allCases) { c in
                            Circle()
                                .fill(c.color)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    if c == color {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { withAnimation(.snappy) { color = c } }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(symbol == icon ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(symbol == icon ? color.color : Color.primary.opacity(0.06))
                                )
                                .onTapGesture { withAnimation(.snappy) { icon = symbol } }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(project == nil ? "Create" : "Save") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { if project == nil { nameFocused = true } }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 560)
        #else
        .presentationDetents([.large])
        #endif
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let project {
            project.name = trimmedName
            project.key = key
            project.summary = summary
            project.color = color
            project.icon = icon
            onSave(project)
        } else {
            let order = (projects.map(\.sortOrder).max() ?? -1) + 1
            let created = Project(name: trimmedName, key: key, summary: summary, color: color, icon: icon, sortOrder: order)
            context.insert(created)
            onSave(created)
        }
        dismiss()
    }
}
