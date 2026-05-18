import AppKit
import SwiftUI
import WebKit

struct WebViewPane: View {
    @Bindable var state: WebViewTabState
    let focused: Bool
    let onFocus: () -> Void
    @State private var addressText: String = ""
    @State private var coordinator = WebViewCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(MuxyTheme.border).frame(height: 1)
            WebViewBridge(state: state, coordinator: coordinator)
                .background(MuxyTheme.bg)
        }
        .background(MuxyTheme.bg)
        .contentShape(Rectangle())
        .onTapGesture { onFocus() }
        .onAppear {
            addressText = state.urlString
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            IconButton(symbol: "chevron.left", size: 12, accessibilityLabel: "Back") {
                coordinator.webView?.goBack()
            }
            .disabled(!state.canGoBack)
            .opacity(state.canGoBack ? 1 : 0.4)

            IconButton(symbol: "chevron.right", size: 12, accessibilityLabel: "Forward") {
                coordinator.webView?.goForward()
            }
            .disabled(!state.canGoForward)
            .opacity(state.canGoForward ? 1 : 0.4)

            IconButton(
                symbol: state.isLoading ? "xmark" : "arrow.clockwise",
                size: 12,
                accessibilityLabel: state.isLoading ? "Stop" : "Reload"
            ) {
                if state.isLoading {
                    coordinator.webView?.stopLoading()
                } else {
                    coordinator.webView?.reload()
                }
            }

            TextField("Enter URL or search", text: $addressText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MuxyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(MuxyTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onSubmit {
                    state.requestLoad(Self.normalize(addressText))
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 36)
        .background(MuxyTheme.bg)
    }

    static func normalize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "about:blank" }
        if trimmed.contains("://") { return trimmed }
        if trimmed.contains(" ") || !trimmed.contains(".") {
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            return "https://www.google.com/search?q=\(query)"
        }
        return "https://\(trimmed)"
    }
}

@MainActor
@Observable
final class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var webView: WKWebView?
    weak var state: WebViewTabState?
    private var lastLoadedVersion = -1

    func bind(webView: WKWebView, state: WebViewTabState) {
        self.webView = webView
        self.state = state
        webView.navigationDelegate = self
        loadIfNeeded(force: true)
    }

    func loadIfNeeded(force: Bool = false) {
        guard let webView, let state else { return }
        if !force, lastLoadedVersion == state.loadVersion { return }
        lastLoadedVersion = state.loadVersion
        guard let url = URL(string: state.urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        Task { @MainActor in
            state?.isLoading = true
            updateNavigationState(webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        Task { @MainActor in
            state?.isLoading = false
            if let title = webView.title, !title.isEmpty {
                state?.displayTitle = title
            }
            updateNavigationState(webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        Task { @MainActor in
            state?.isLoading = false
            updateNavigationState(webView)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError _: Error
    ) {
        Task { @MainActor in
            state?.isLoading = false
            updateNavigationState(webView)
        }
    }

    @MainActor
    private func updateNavigationState(_ webView: WKWebView) {
        state?.canGoBack = webView.canGoBack
        state?.canGoForward = webView.canGoForward
    }
}

private struct WebViewBridge: NSViewRepresentable {
    let state: WebViewTabState
    let coordinator: WebViewCoordinator

    func makeNSView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        coordinator.bind(webView: webView, state: state)
        return webView
    }

    func updateNSView(_: WKWebView, context _: Context) {
        coordinator.loadIfNeeded()
    }
}
