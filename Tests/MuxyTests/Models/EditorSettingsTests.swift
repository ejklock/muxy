import Foundation
import Testing

@testable import Muxy

@Suite("EditorSettings")
@MainActor
struct EditorSettingsTests {
    @Test("DefaultEditor includes vscodeServer case with correct displayName")
    func vscodeServerCase() {
        let editor = EditorSettings.DefaultEditor.vscodeServer
        #expect(editor.displayName == "VS Code Server")
        #expect(editor.id == "vscodeServer")
    }

    @Test("DefaultEditor allCases includes vscodeServer")
    func allCasesContainsVSCodeServer() {
        #expect(EditorSettings.DefaultEditor.allCases.contains(.vscodeServer))
    }

    @Test("DefaultEditor rawValues are stable")
    func rawValues() {
        #expect(EditorSettings.DefaultEditor.builtIn.rawValue == "builtIn")
        #expect(EditorSettings.DefaultEditor.terminalCommand.rawValue == "terminalCommand")
        #expect(EditorSettings.DefaultEditor.vscodeServer.rawValue == "vscodeServer")
    }
}
