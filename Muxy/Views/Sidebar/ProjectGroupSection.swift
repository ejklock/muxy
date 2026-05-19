import SwiftUI

struct WorkspaceSwitcher: View {
    let isWide: Bool

    @Environment(ProjectGroupStore.self) private var groupStore

    @State private var isRenamingID: UUID?
    @State private var renameText = ""
    @State private var isCreatingNew = false
    @State private var newWorkspaceName = ""
    @State private var isShowingPopover = false
    @State private var isTriggerHovered = false

    private var activeGroup: ProjectGroup? {
        guard let id = groupStore.activeGroupID else { return nil }
        return groupStore.groups.first(where: { $0.id == id })
    }

    private var activeLabel: String {
        activeGroup?.name ?? "All Projects"
    }

    var body: some View {
        if isWide {
            wideLayout
        } else {
            collapsedLayout
        }
    }

    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: UIMetrics.spacing1) {
            Button {
                isShowingPopover.toggle()
            } label: {
                HStack(spacing: UIMetrics.spacing2) {
                    Text(activeLabel)
                        .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                        .foregroundStyle(MuxyTheme.fgMuted)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                        .foregroundStyle(MuxyTheme.fgMuted)
                    Spacer()
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

            if isCreatingNew {
                newWorkspaceField
            }
        }
    }

    private var collapsedLayout: some View {
        VStack(spacing: UIMetrics.spacing1) {
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

            if isCreatingNew {
                newWorkspaceField
            }
        }
    }

    private var workspacePopover: some View {
        VStack(alignment: .leading, spacing: UIMetrics.spacing1) {
            allProjectsRow
            Divider()
                .padding(.vertical, UIMetrics.spacing1)
            ForEach(groupStore.groups) { group in
                workspacePopoverRow(group)
            }
            if !groupStore.groups.isEmpty {
                Divider()
                    .padding(.vertical, UIMetrics.spacing1)
            }
            newWorkspaceButton
            if isCreatingNew {
                newWorkspaceField
            }
        }
        .padding(UIMetrics.spacing3)
        .frame(minWidth: 180)
    }

    private var allProjectsRow: some View {
        Button {
            groupStore.clearGroupSelection()
            isShowingPopover = false
        } label: {
            HStack(spacing: UIMetrics.spacing2) {
                Image(systemName: groupStore.activeGroupID == nil ? "checkmark" : "")
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

    @ViewBuilder
    private func workspacePopoverRow(_ group: ProjectGroup) -> some View {
        if isRenamingID == group.id {
            renameField(for: group)
        } else {
            workspaceSelectRow(group)
        }
    }

    private func workspaceSelectRow(_ group: ProjectGroup) -> some View {
        WorkspaceRow(
            group: group,
            isActive: groupStore.activeGroupID == group.id,
            onSelect: {
                groupStore.selectGroup(id: group.id)
                isShowingPopover = false
            },
            onRename: {
                isRenamingID = group.id
                renameText = group.name
            },
            onDelete: {
                groupStore.removeGroup(id: group.id)
            }
        )
    }

    private func renameField(for group: ProjectGroup) -> some View {
        TextField("Workspace name", text: $renameText)
            .textFieldStyle(.plain)
            .font(.system(size: UIMetrics.fontBody, weight: .medium))
            .foregroundStyle(MuxyTheme.fg)
            .padding(.horizontal, UIMetrics.spacing3)
            .padding(.vertical, UIMetrics.spacing2)
            .background(MuxyTheme.surface, in: RoundedRectangle(cornerRadius: UIMetrics.radiusMD))
            .onSubmit { commitRename(id: group.id) }
            .onExitCommand { cancelRename() }
    }

    private var newWorkspaceButton: some View {
        Button {
            isCreatingNew = true
            newWorkspaceName = ""
        } label: {
            HStack(spacing: UIMetrics.spacing2) {
                Image(systemName: "plus")
                    .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
                Text("New Workspace")
                    .font(.system(size: UIMetrics.fontBody, weight: .medium))
                    .foregroundStyle(MuxyTheme.fgMuted)
                Spacer()
            }
            .padding(.horizontal, UIMetrics.spacing3)
            .padding(.vertical, UIMetrics.spacing2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var newWorkspaceField: some View {
        TextField("Workspace name", text: $newWorkspaceName)
            .textFieldStyle(.plain)
            .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
            .foregroundStyle(MuxyTheme.fgMuted)
            .padding(.horizontal, UIMetrics.spacing2)
            .padding(.vertical, UIMetrics.spacing1)
            .background(MuxyTheme.surface, in: RoundedRectangle(cornerRadius: UIMetrics.radiusMD))
            .onSubmit { commitNewWorkspace() }
            .onExitCommand { cancelNewWorkspace() }
    }

    private func commitRename(id: UUID) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelRename()
            return
        }
        groupStore.renameGroup(id: id, to: trimmed)
        isRenamingID = nil
        renameText = ""
    }

    private func cancelRename() {
        isRenamingID = nil
        renameText = ""
    }

    private func commitNewWorkspace() {
        let trimmed = newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelNewWorkspace()
            return
        }
        groupStore.addGroup(name: trimmed)
        isCreatingNew = false
        newWorkspaceName = ""
    }

    private func cancelNewWorkspace() {
        isCreatingNew = false
        newWorkspaceName = ""
    }
}

private struct WorkspaceRow: View {
    let group: ProjectGroup
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
                Text(group.name)
                    .font(.system(size: UIMetrics.fontBody, weight: .medium))
                    .foregroundStyle(MuxyTheme.fg)
                    .lineLimit(1)
                Spacer()
                if isHovered {
                    HStack(spacing: UIMetrics.spacing1) {
                        Button(action: onRename) {
                            Image(systemName: "pencil")
                                .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                                .foregroundStyle(MuxyTheme.fgMuted)
                        }
                        .buttonStyle(.plain)
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: UIMetrics.fontCaption, weight: .semibold))
                                .foregroundStyle(MuxyTheme.fgMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, UIMetrics.spacing3)
            .padding(.vertical, UIMetrics.spacing2)
            .background(isHovered ? MuxyTheme.hover : Color.clear, in: RoundedRectangle(cornerRadius: UIMetrics.radiusMD))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
