import Foundation
import Testing

@testable import Muxy

@Suite("ProjectWorkspaceStore")
@MainActor
struct ProjectWorkspaceStoreTests {
    @Test("addWorkspace appends a new workspace and persists it")
    func addWorkspace() {
        let persistence = ProjectWorkspacePersistenceStub()
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.addWorkspace(name: "Work")

        #expect(store.workspaces.count == 1)
        #expect(store.workspaces.first?.name == "Work")
        #expect(persistence.savedWorkspaces?.count == 1)
    }

    @Test("removeWorkspace deletes the workspace and persists")
    func removeWorkspace() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.removeWorkspace(id: workspace.id)

        #expect(store.workspaces.isEmpty)
        #expect(persistence.savedWorkspaces?.isEmpty == true)
    }

    @Test("removeWorkspace clears activeWorkspaceID when active workspace is deleted")
    func removeWorkspaceClearsActiveWorkspace() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)
        store.selectWorkspace(id: workspace.id)

        store.removeWorkspace(id: workspace.id)

        #expect(store.activeWorkspaceID == nil)
    }

    @Test("renameWorkspace updates the name and persists")
    func renameWorkspace() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.renameWorkspace(id: workspace.id, to: "Personal")

        #expect(store.workspaces.first?.name == "Personal")
        #expect(persistence.savedWorkspaces?.first?.name == "Personal")
    }

    @Test("renameWorkspace with unknown id is a no-op")
    func renameWorkspaceUnknownID() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.renameWorkspace(id: UUID(), to: "Other")

        #expect(store.workspaces.first?.name == "Work")
    }

    @Test("addProject adds projectID to the workspace and persists")
    func addProject() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)
        let projectID = UUID()

        store.addProject(projectID: projectID, toWorkspace: workspace.id)

        #expect(store.workspaces.first?.projectIDs == [projectID])
        #expect(persistence.savedWorkspaces?.first?.projectIDs == [projectID])
    }

    @Test("addProject ignores duplicate projectID")
    func addProjectDuplicate() {
        let projectID = UUID()
        let workspace = ProjectWorkspace(name: "Work", projectIDs: [projectID])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.addProject(projectID: projectID, toWorkspace: workspace.id)

        #expect(store.workspaces.first?.projectIDs.count == 1)
    }

    @Test("removeProject removes projectID from the workspace and persists")
    func removeProject() {
        let projectID = UUID()
        let workspace = ProjectWorkspace(name: "Work", projectIDs: [projectID])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.removeProject(projectID: projectID, fromWorkspace: workspace.id)

        #expect(store.workspaces.first?.projectIDs.isEmpty == true)
        #expect(persistence.savedWorkspaces?.first?.projectIDs.isEmpty == true)
    }

    @Test("load on empty persistence yields empty workspaces")
    func loadEmptyIsEmpty() {
        let persistence = ProjectWorkspacePersistenceStub(initial: [])
        let store = ProjectWorkspaceStore(persistence: persistence)

        #expect(store.workspaces.isEmpty)
    }

    @Test("load sorts workspaces by sortOrder")
    func loadSortsByOrder() {
        let second = ProjectWorkspace(name: "B", sortOrder: 1)
        let first = ProjectWorkspace(name: "A", sortOrder: 0)
        let persistence = ProjectWorkspacePersistenceStub(initial: [second, first])
        let store = ProjectWorkspaceStore(persistence: persistence)

        #expect(store.workspaces.first?.name == "A")
        #expect(store.workspaces.last?.name == "B")
    }

    @Test("addWorkspace assigns sequential sortOrder")
    func addWorkspaceSortOrder() {
        let persistence = ProjectWorkspacePersistenceStub(initial: [])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.addWorkspace(name: "First")
        store.addWorkspace(name: "Second")

        #expect(store.workspaces[0].sortOrder == 0)
        #expect(store.workspaces[1].sortOrder == 1)
    }

    @Test("activeWorkspaceID is nil by default")
    func activeWorkspaceIDDefaultsToNil() {
        let persistence = ProjectWorkspacePersistenceStub(initial: [])
        let store = ProjectWorkspaceStore(persistence: persistence)

        #expect(store.activeWorkspaceID == nil)
    }

    @Test("selectWorkspace sets activeWorkspaceID")
    func selectWorkspace() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.selectWorkspace(id: workspace.id)

        #expect(store.activeWorkspaceID == workspace.id)
    }

    @Test("clearWorkspaceSelection resets activeWorkspaceID to nil")
    func clearWorkspaceSelection() {
        let workspace = ProjectWorkspace(name: "Work")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)
        store.selectWorkspace(id: workspace.id)

        store.clearWorkspaceSelection()

        #expect(store.activeWorkspaceID == nil)
    }

    @Test("filteredProjects returns all projects when activeWorkspaceID is nil")
    func filteredProjectsAllWhenNoSelection() {
        let persistence = ProjectWorkspacePersistenceStub(initial: [])
        let store = ProjectWorkspaceStore(persistence: persistence)
        let projects = [
            Project(name: "A", path: "/a"),
            Project(name: "B", path: "/b")
        ]

        let result = store.filteredProjects(from: projects)

        #expect(result.count == 2)
    }

    @Test("filteredProjects returns only workspace projects when a workspace is selected")
    func filteredProjectsActiveWorkspace() {
        let projectA = Project(name: "A", path: "/a")
        let projectB = Project(name: "B", path: "/b")
        let workspace = ProjectWorkspace(name: "Work", projectIDs: [projectA.id])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)
        store.selectWorkspace(id: workspace.id)

        let result = store.filteredProjects(from: [projectA, projectB])

        #expect(result.count == 1)
        #expect(result.first?.id == projectA.id)
    }

    @Test("filteredProjects returns all projects when activeWorkspaceID does not match any workspace")
    func filteredProjectsUnknownActiveWorkspace() {
        let persistence = ProjectWorkspacePersistenceStub(initial: [])
        let store = ProjectWorkspaceStore(persistence: persistence)
        store.selectWorkspace(id: UUID())
        let projects = [Project(name: "A", path: "/a")]

        let result = store.filteredProjects(from: projects)

        #expect(result.count == 1)
    }

    @Test("filteredProjects returns empty array when workspace has no matching projects")
    func filteredProjectsEmptyWorkspace() {
        let workspace = ProjectWorkspace(name: "Empty")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)
        store.selectWorkspace(id: workspace.id)
        let projects = [Project(name: "A", path: "/a")]

        let result = store.filteredProjects(from: projects)

        #expect(result.isEmpty)
    }
}

final class ProjectWorkspacePersistenceStub: ProjectWorkspacePersisting {
    var workspaces: [ProjectWorkspace]
    var savedWorkspaces: [ProjectWorkspace]?

    init(initial: [ProjectWorkspace] = []) {
        workspaces = initial
    }

    func loadProjectWorkspaces() throws -> [ProjectWorkspace] {
        workspaces
    }

    func saveProjectWorkspaces(_ workspaces: [ProjectWorkspace]) throws {
        savedWorkspaces = workspaces
        self.workspaces = workspaces
    }
}
