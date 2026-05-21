import Foundation

protocol ProjectWorkspacePersisting {
    func loadProjectWorkspaces() throws -> [ProjectWorkspace]
    func saveProjectWorkspaces(_ workspaces: [ProjectWorkspace]) throws
}

final class FileProjectWorkspacePersistence: ProjectWorkspacePersisting {
    private let store: CodableFileStore<[ProjectWorkspace]>

    init(fileURL: URL = MuxyFileStorage.fileURL(filename: "project-workspaces.json")) {
        store = CodableFileStore(fileURL: fileURL)
    }

    func loadProjectWorkspaces() throws -> [ProjectWorkspace] {
        try store.load() ?? []
    }

    func saveProjectWorkspaces(_ workspaces: [ProjectWorkspace]) throws {
        try store.save(workspaces)
    }
}
