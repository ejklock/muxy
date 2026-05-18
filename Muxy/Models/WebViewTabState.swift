import Foundation

@MainActor
@Observable
final class WebViewTabState: Identifiable {
    let id = UUID()
    let projectPath: String
    var urlString: String
    var displayTitle: String
    var isLoading = false
    var canGoBack = false
    var canGoForward = false
    var loadVersion = 0

    init(projectPath: String, urlString: String = "https://www.google.com") {
        self.projectPath = projectPath
        self.urlString = urlString
        displayTitle = "Browser"
    }

    func requestLoad(_ urlString: String) {
        self.urlString = urlString
        loadVersion &+= 1
    }
}
