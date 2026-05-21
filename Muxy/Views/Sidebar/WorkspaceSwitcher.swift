import SwiftUI

struct WorkspaceSwitcher: View {
    let isWide: Bool

    @Environment(ProjectWorkspaceStore.self) private var projectWorkspaceStore

    @State private var isShowingPopover = false
    @State private var isTriggerHovered = false
    @State private var editorMode: WorkspaceEditorMode?
    @State private var workspacePendingDelete: ProjectWorkspace?

    private var activeWorkspace: ProjectWorkspace? {
        guard let id = projectWorkspaceStore.activeWorkspaceID else { return nil }
        return projectWorkspaceStore.workspaces.first(where: { $0.id == id })
    }

    private var activeLabel: String {
        activeWorkspace?.name ?? "All Projects"
    }

    var body: some View {
        Group {
            if isWide {
                wideLayout
            } else {
                collapsedLayout
            }
        }
        .sheet(item: $editorMode) { mode in
            WorkspaceEditorSheet(
                mode: mode,
                onSubmit: { name in
                    apply(mode: mode, name: name)
                    editorMode = nil
                },
                onCancel: { editorMode = nil }
            )
        }
        .alert(
            "Delete “\(workspacePendingDelete?.name ?? "")”?",
            isPresented: deleteAlertBinding,
            presenting: workspacePendingDelete
        ) { workspace in
            Button("Delete", role: .destructive) {
                projectWorkspaceStore.removeWorkspace(id: workspace.id)
                workspacePendingDelete = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                workspacePendingDelete = nil
            }
        } message: { _ in
            Text("Projects in this workspace will not be deleted.")
        }
    }

    private var wideLayout: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            HStack(spacing: UIMetrics.spacing2) {
                Text(activeLabel)
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
            }
            .padding(.horizontal, UIMetrics.spacing4)
            .padding(.vertical, UIMetrics.spacing3)
            .background(
                isTriggerHovered ? MuxyTheme.hover : MuxyTheme.surface,
                in: RoundedRectangle(cornerRadius: UIMetrics.radiusMD)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isTriggerHovered = $0 }
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            workspacePopover
        }
    }

    private var collapsedLayout: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                .foregroundStyle(MuxyTheme.fgMuted)
                .frame(width: UIMetrics.iconXXL, height: UIMetrics.iconXXL)
                .background(
                    isTriggerHovered ? MuxyTheme.hover : MuxyTheme.surface,
                    in: RoundedRectangle(cornerRadius: UIMetrics.radiusSM)
                )
        }
        .buttonStyle(.plain)
        .onHover { isTriggerHovered = $0 }
        .popover(isPresented: $isShowingPopover, arrowEdge: .trailing) {
            workspacePopover
        }
    }

    private var workspacePopover: some View {
        VStack(alignment: .leading, spacing: UIMetrics.spacing1) {
            allProjectsRow
            Divider()
                .padding(.vertical, UIMetrics.spacing1)
            ForEach(projectWorkspaceStore.workspaces) { workspace in
                WorkspaceRow(
                    workspace: workspace,
                    isActive: projectWorkspaceStore.activeWorkspaceID == workspace.id,
                    onSelect: {
                        projectWorkspaceStore.selectWorkspace(id: workspace.id)
                        isShowingPopover = false
                    },
                    onRename: {
                        isShowingPopover = false
                        editorMode = .rename(workspace)
                    },
                    onDelete: {
                        isShowingPopover = false
                        workspacePendingDelete = workspace
                    }
                )
            }
            if !projectWorkspaceStore.workspaces.isEmpty {
                Divider()
                    .padding(.vertical, UIMetrics.spacing1)
            }
            newWorkspaceButton
        }
        .padding(UIMetrics.spacing3)
        .frame(minWidth: 180)
    }

    private var allProjectsRow: some View {
        Button {
            projectWorkspaceStore.clearWorkspaceSelection()
            isShowingPopover = false
        } label: {
            HStack(spacing: UIMetrics.spacing2) {
                Image(systemName: projectWorkspaceStore.activeWorkspaceID == nil ? "checkmark" : "")
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.accent)
                    .frame(width: UIMetrics.fontCaption)
                Text("All Projects")
                    .font(.system(size: UIMetrics.fontBody, weight: .medium))
                    .foregroundStyle(MuxyTheme.fg)
                Spacer()
            }
            .padding(.horizontal, UIMetrics.spacing3)
            .padding(.vertical, UIMetrics.spacing2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var newWorkspaceButton: some View {
        Button {
            isShowingPopover = false
            editorMode = .create
        } label: {
            HStack(spacing: UIMetrics.spacing2) {
                Image(systemName: "plus")
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.accent)
                    .frame(width: UIMetrics.fontCaption)
                Text("New Workspace")
                    .font(.system(size: UIMetrics.fontBody, weight: .medium))
                    .foregroundStyle(MuxyTheme.fg)
                Spacer()
            }
            .padding(.horizontal, UIMetrics.spacing3)
            .padding(.vertical, UIMetrics.spacing2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { workspacePendingDelete != nil },
            set: { newValue in
                if !newValue {
                    workspacePendingDelete = nil
                }
            }
        )
    }

    private func apply(mode: WorkspaceEditorMode, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .create:
            projectWorkspaceStore.addWorkspace(name: trimmed)
        case let .rename(workspace):
            projectWorkspaceStore.renameWorkspace(id: workspace.id, to: trimmed)
        }
    }
}

enum WorkspaceEditorMode: Identifiable {
    case create
    case rename(ProjectWorkspace)

    var id: String {
        switch self {
        case .create: "create"
        case let .rename(workspace): "rename-\(workspace.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create: "New Workspace"
        case .rename: "Rename Workspace"
        }
    }

    var actionLabel: String {
        switch self {
        case .create: "Create"
        case .rename: "Rename"
        }
    }

    var initialName: String {
        switch self {
        case .create: ""
        case let .rename(workspace): workspace.name
        }
    }
}

struct WorkspaceMembershipMenu: View {
    let project: Project

    @Environment(ProjectWorkspaceStore.self) private var projectWorkspaceStore

    var body: some View {
        Menu("Move to Workspace") {
            ForEach(projectWorkspaceStore.workspaces) { workspace in
                let isInWorkspace = workspace.projectIDs.contains(project.id)
                Button {
                    if isInWorkspace {
                        projectWorkspaceStore.removeProject(projectID: project.id, fromWorkspace: workspace.id)
                    } else {
                        projectWorkspaceStore.addProject(projectID: project.id, toWorkspace: workspace.id)
                    }
                } label: {
                    Label(workspace.name, systemImage: isInWorkspace ? "checkmark" : "")
                }
            }
        }
    }
}

private struct WorkspaceRow: View {
    let workspace: ProjectWorkspace
    let isActive: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: UIMetrics.spacing2) {
                Image(systemName: isActive ? "checkmark" : "")
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.accent)
                    .frame(width: UIMetrics.fontCaption)
                Text(workspace.name)
                    .font(.system(size: UIMetrics.fontBody, weight: .medium))
                    .foregroundStyle(MuxyTheme.fg)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, UIMetrics.spacing3)
            .padding(.vertical, UIMetrics.spacing2)
            .background(isHovered ? MuxyTheme.hover : Color.clear, in: RoundedRectangle(cornerRadius: UIMetrics.radiusMD))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Rename", action: onRename)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

private struct WorkspaceEditorSheet: View {
    let mode: WorkspaceEditorMode
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var canSubmit: Bool {
        !trimmed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UIMetrics.scaled(14)) {
            Text(mode.title)
                .font(.system(size: UIMetrics.fontHeadline, weight: .semibold))

            VStack(alignment: .leading, spacing: UIMetrics.spacing3) {
                Text("Workspace Name")
                    .font(.system(size: UIMetrics.fontFootnote))
                    .foregroundStyle(MuxyTheme.fgMuted)
                TextField("Personal", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit { if canSubmit { onSubmit(trimmed) } }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(mode.actionLabel) { onSubmit(trimmed) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(UIMetrics.spacing8)
        .frame(width: UIMetrics.scaled(360))
        .onAppear {
            name = mode.initialName
            nameFocused = true
        }
    }
}
