import Foundation
import Testing

@testable import Muxy

@Suite("Sidebar workspace integration")
@MainActor
struct SidebarWorkspaceTests {
    @Test("removeProjectFromAllWorkspaces removes project from every workspace that contains it")
    func removeProjectFromAllWorkspaces() {
        let projectID = UUID()
        let workspaceA = ProjectWorkspace(name: "A", projectIDs: [projectID])
        let workspaceB = ProjectWorkspace(name: "B", projectIDs: [UUID()])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspaceA, workspaceB])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.removeProjectFromAllWorkspaces(projectID: projectID)

        #expect(store.workspaces.first(where: { $0.id == workspaceA.id })?.projectIDs.isEmpty == true)
        #expect(store.workspaces.first(where: { $0.id == workspaceB.id })?.projectIDs.count == 1)
    }

    @Test("removeProjectFromAllWorkspaces on unknown projectID is a no-op")
    func removeProjectFromAllWorkspacesUnknown() {
        let projectID = UUID()
        let workspace = ProjectWorkspace(name: "A", projectIDs: [projectID])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.removeProjectFromAllWorkspaces(projectID: UUID())

        #expect(store.workspaces.first?.projectIDs == [projectID])
    }

    @Test("removeProjectFromAllWorkspaces persists changes")
    func removeProjectFromAllWorkspacesPersists() {
        let projectID = UUID()
        let workspace = ProjectWorkspace(name: "Work", projectIDs: [projectID])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.removeProjectFromAllWorkspaces(projectID: projectID)

        #expect(persistence.savedWorkspaces?.first?.projectIDs.isEmpty == true)
    }

    @Test("ProjectStore onProjectRemoved callback fires after remove")
    func projectStoreRemoveCallbackFires() {
        let project = Project(name: "Test", path: "/tmp/test")
        let persistence = ProjectPersistenceStub(initial: [project])
        let store = ProjectStore(persistence: persistence)
        var receivedID: UUID?

        store.onProjectRemoved = { receivedID = $0 }
        store.remove(id: project.id)

        #expect(receivedID == project.id)
    }

    @Test("ProjectStore onProjectRemoved is nil-safe when no callback set")
    func projectStoreRemoveNoCallback() {
        let project = Project(name: "Test", path: "/tmp/test")
        let persistence = ProjectPersistenceStub(initial: [project])
        let store = ProjectStore(persistence: persistence)

        store.remove(id: project.id)

        #expect(store.projects.isEmpty)
    }

    @Test("workspace selection survives unrelated workspace renames")
    func workspaceSelectionSurvivesUnrelatedChanges() {
        let workspaceA = ProjectWorkspace(name: "A")
        let workspaceB = ProjectWorkspace(name: "B")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspaceA, workspaceB])
        let store = ProjectWorkspaceStore(persistence: persistence)
        store.selectWorkspace(id: workspaceA.id)

        store.renameWorkspace(id: workspaceB.id, to: "B Renamed")

        #expect(store.activeWorkspaceID == workspaceA.id)
    }

    @Test("addProject removes project from other workspaces (single-membership)")
    func addProjectIsExclusive() {
        let projectID = UUID()
        let workspaceA = ProjectWorkspace(name: "A", projectIDs: [projectID])
        let workspaceB = ProjectWorkspace(name: "B")
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspaceA, workspaceB])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.addProject(projectID: projectID, toWorkspace: workspaceB.id)

        #expect(store.workspaces.first(where: { $0.id == workspaceA.id })?.projectIDs.contains(projectID) == false)
        #expect(store.workspaces.first(where: { $0.id == workspaceB.id })?.projectIDs.contains(projectID) == true)
    }

    @Test("filteredProjects after workspace selection only shows workspace projects")
    func filteredProjectsAfterSelection() {
        let projectA = Project(name: "A", path: "/a")
        let projectB = Project(name: "B", path: "/b")
        let workspace = ProjectWorkspace(name: "Work", projectIDs: [projectA.id])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.selectWorkspace(id: workspace.id)
        let filtered = store.filteredProjects(from: [projectA, projectB])

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == projectA.id)
    }

    @Test("filteredProjects after clearWorkspaceSelection shows all projects")
    func filteredProjectsAfterClearSelection() {
        let projectA = Project(name: "A", path: "/a")
        let projectB = Project(name: "B", path: "/b")
        let workspace = ProjectWorkspace(name: "Work", projectIDs: [projectA.id])
        let persistence = ProjectWorkspacePersistenceStub(initial: [workspace])
        let store = ProjectWorkspaceStore(persistence: persistence)

        store.selectWorkspace(id: workspace.id)
        store.clearWorkspaceSelection()
        let filtered = store.filteredProjects(from: [projectA, projectB])

        #expect(filtered.count == 2)
    }
}

private final class ProjectPersistenceStub: ProjectPersisting {
    var projects: [Project]

    init(initial: [Project]) {
        projects = initial
    }

    func loadProjects() throws -> [Project] {
        projects
    }

    func saveProjects(_ projects: [Project]) throws {
        self.projects = projects
    }
}
