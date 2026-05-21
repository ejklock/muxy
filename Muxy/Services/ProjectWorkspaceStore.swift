import Foundation
import os

private let logger = Logger(subsystem: "app.muxy", category: "ProjectWorkspaceStore")

@MainActor
@Observable
final class ProjectWorkspaceStore {
    private(set) var workspaces: [ProjectWorkspace] = []
    private(set) var activeWorkspaceID: UUID?
    private let persistence: any ProjectWorkspacePersisting

    init(persistence: any ProjectWorkspacePersisting) {
        self.persistence = persistence
        load()
    }

    func selectWorkspace(id: UUID) {
        activeWorkspaceID = id
    }

    func clearWorkspaceSelection() {
        activeWorkspaceID = nil
    }

    func filteredProjects(from projects: [Project]) -> [Project] {
        guard let activeWorkspaceID else { return projects }
        guard let workspace = workspaces.first(where: { $0.id == activeWorkspaceID }) else { return projects }
        return projects.filter { workspace.projectIDs.contains($0.id) }
    }

    func addWorkspace(name: String) {
        let sortOrder = workspaces.count
        let workspace = ProjectWorkspace(name: name, sortOrder: sortOrder)
        workspaces.append(workspace)
        save()
    }

    func removeWorkspace(id: UUID) {
        if activeWorkspaceID == id {
            activeWorkspaceID = nil
        }
        workspaces.removeAll { $0.id == id }
        save()
    }

    func renameWorkspace(id: UUID, to newName: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].name = newName
        save()
    }

    func addProject(projectID: UUID, toWorkspace workspaceID: UUID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        for otherIndex in workspaces.indices where otherIndex != index {
            workspaces[otherIndex].projectIDs.removeAll { $0 == projectID }
        }
        if !workspaces[index].projectIDs.contains(projectID) {
            workspaces[index].projectIDs.append(projectID)
        }
        save()
    }

    func removeProject(projectID: UUID, fromWorkspace workspaceID: UUID) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        workspaces[index].projectIDs.removeAll { $0 == projectID }
        save()
    }

    func removeProjectFromAllWorkspaces(projectID: UUID) {
        for index in workspaces.indices {
            workspaces[index].projectIDs.removeAll { $0 == projectID }
        }
        save()
    }

    private func save() {
        do {
            try persistence.saveProjectWorkspaces(workspaces)
        } catch {
            logger.error("Failed to save project workspaces: \(error)")
        }
    }

    private func load() {
        do {
            let loaded = try persistence.loadProjectWorkspaces()
            workspaces = loaded.sorted { $0.sortOrder < $1.sortOrder }
        } catch {
            logger.error("Failed to load project workspaces: \(error)")
        }
    }
}
