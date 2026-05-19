import Foundation
import Testing

@testable import Muxy

@Suite("AppState VS Code Server")
@MainActor
struct AppStateVSCodeServerTests {
    private let projectPath = "/tmp/project"

    private func makeHarness(projectPath: String = "/tmp/project") -> Harness {
        let projectID = UUID()
        let worktreeID = UUID()
        let key = WorktreeKey(projectID: projectID, worktreeID: worktreeID)
        let area = TabArea(projectPath: projectPath)
        let appState = AppState(
            selectionStore: VSCodeSelectionStoreStub(),
            terminalViews: VSCodeTerminalViewStub(),
            workspacePersistence: VSCodeWorkspacePersistenceStub()
        )
        appState.activeProjectID = projectID
        appState.activeWorktreeID[projectID] = worktreeID
        appState.workspaceRoots[key] = .tabArea(area)
        appState.focusedAreaID[key] = area.id
        return Harness(appState: appState, projectID: projectID, area: area)
    }

    @Test("openFile with vscodeServer creates webView tab with correct URL")
    func openFileCreatesWebViewTab() {
        let harness = makeHarness()
        EditorSettings.shared.defaultEditor = .vscodeServer
        EditorSettings.shared.vscodeServerURL = "http://localhost:8080"
        defer { EditorSettings.shared.defaultEditor = .builtIn }

        harness.appState.openFile(
            "/tmp/project/Sources/main.swift",
            projectID: harness.projectID
        )

        let tab = harness.area.activeTab
        #expect(tab?.kind == .webView)
        let urlString = tab?.content.webViewState?.urlString ?? ""
        #expect(urlString.hasPrefix("http://localhost:8080/?folder=/tmp/project"))
        #expect(!urlString.contains("goto"))
    }

    @Test("openFile with vscodeServer and line appends goto param with relative path")
    func openFileWithLineAppendsGoto() {
        let harness = makeHarness()
        EditorSettings.shared.defaultEditor = .vscodeServer
        EditorSettings.shared.vscodeServerURL = "http://localhost:8080"
        defer { EditorSettings.shared.defaultEditor = .builtIn }

        harness.appState.openFile(
            "/tmp/project/Sources/main.swift",
            projectID: harness.projectID,
            line: 42,
            column: 10
        )

        let urlString = harness.area.activeTab?.content.webViewState?.urlString ?? ""
        #expect(urlString.contains("goto=Sources/main.swift:42:10"))
    }

    @Test("openFile with vscodeServer and no line omits goto param")
    func openFileWithoutLineOmitsGoto() {
        let harness = makeHarness()
        EditorSettings.shared.defaultEditor = .vscodeServer
        EditorSettings.shared.vscodeServerURL = "http://localhost:8080"
        defer { EditorSettings.shared.defaultEditor = .builtIn }

        harness.appState.openFile(
            "/tmp/project/README.md",
            projectID: harness.projectID
        )

        let urlString = harness.area.activeTab?.content.webViewState?.urlString ?? ""
        #expect(!urlString.contains("goto"))
    }

    @Test("openFile with vscodeServer reuses existing webView tab with matching base URL")
    func openFileReusesExistingWebViewTab() {
        let harness = makeHarness()
        EditorSettings.shared.defaultEditor = .vscodeServer
        EditorSettings.shared.vscodeServerURL = "http://localhost:8080"
        defer { EditorSettings.shared.defaultEditor = .builtIn }

        harness.appState.openFile(
            "/tmp/project/Sources/main.swift",
            projectID: harness.projectID
        )
        let firstTabCount = harness.area.tabs.count

        harness.appState.openFile(
            "/tmp/project/Sources/App.swift",
            projectID: harness.projectID,
            line: 5,
            column: 1
        )

        #expect(harness.area.tabs.count == firstTabCount)
        let urlString = harness.area.activeTab?.content.webViewState?.urlString ?? ""
        #expect(urlString.contains("App.swift"))
    }

    @Test("openFile with vscodeServer uses file name as tab title")
    func openFileUsesFileNameAsTitle() {
        let harness = makeHarness()
        EditorSettings.shared.defaultEditor = .vscodeServer
        EditorSettings.shared.vscodeServerURL = "http://localhost:8080"
        defer { EditorSettings.shared.defaultEditor = .builtIn }

        harness.appState.openFile(
            "/tmp/project/Sources/main.swift",
            projectID: harness.projectID
        )

        #expect(harness.area.activeTab?.content.webViewState?.displayTitle == "main.swift")
    }

    private struct Harness {
        let appState: AppState
        let projectID: UUID
        let area: TabArea
    }
}

@MainActor
private final class VSCodeSelectionStoreStub: ActiveProjectSelectionStoring {
    private var activeProjectID: UUID?
    private var activeWorktreeIDs: [UUID: UUID] = [:]
    func loadActiveProjectID() -> UUID? { activeProjectID }
    func saveActiveProjectID(_ id: UUID?) { activeProjectID = id }
    func loadActiveWorktreeIDs() -> [UUID: UUID] { activeWorktreeIDs }
    func saveActiveWorktreeIDs(_ ids: [UUID: UUID]) { activeWorktreeIDs = ids }
}

@MainActor
private final class VSCodeTerminalViewStub: TerminalViewRemoving {
    func removeView(for _: UUID) {}
    func needsConfirmQuit(for _: UUID) -> Bool { false }
}

private final class VSCodeWorkspacePersistenceStub: WorkspacePersisting {
    func loadWorkspaces() throws -> [WorkspaceSnapshot] { [] }
    func saveWorkspaces(_: [WorkspaceSnapshot]) throws {}
}
