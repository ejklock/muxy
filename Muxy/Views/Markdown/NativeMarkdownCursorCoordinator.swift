import AppKit

@MainActor
final class NativeMarkdownCursorCoordinator {
    fileprivate enum CursorDecision: Equatable {
        case pointingHand
        case textSelection
    }

    fileprivate struct CursorHit {
        let decision: CursorDecision
        let hoveredTextView: NativeMarkdownSelectableTextView?
        let hoveredLinkRange: NSRange?
    }

    private weak var scrollView: NSScrollView?
    private var localEventMonitor: Any?
    private var updateScheduled = false
    private var lastAppliedDecision: CursorDecision?

    deinit {
        MainActor.assumeIsolated {
            if let localEventMonitor {
                NSEvent.removeMonitor(localEventMonitor)
            }
        }
    }

    func attach(to scrollView: NSScrollView) {
        if self.scrollView === scrollView {
            scrollView.window?.acceptsMouseMovedEvents = true
            scheduleUpdate()
            return
        }

        detach()
        self.scrollView = scrollView
        scrollView.window?.acceptsMouseMovedEvents = true
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .cursorUpdate, .leftMouseDragged, .leftMouseDown, .leftMouseUp, .scrollWheel]
        ) { [weak self] event in
            self?.scheduleUpdate(for: event)
            return event
        }
        scheduleUpdate()
    }

    func detach() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        scrollView?.nativeMarkdownClearLinkHovers(except: nil)
        scrollView = nil
        updateScheduled = false
        lastAppliedDecision = nil
    }

    func scheduleUpdateAfterScroll() {
        scheduleUpdate()
    }

    private func scheduleUpdate(for event: NSEvent? = nil) {
        guard let scrollView, let window = scrollView.window else { return }
        if let event, event.window !== window { return }
        window.acceptsMouseMovedEvents = true
        guard !updateScheduled else { return }

        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.updateCursorNow()
        }
    }

    private func updateCursorNow() {
        guard let scrollView, let window = scrollView.window else { return }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        let scrollViewWindowRect = scrollView.convert(scrollView.bounds, to: nil)
        guard scrollViewWindowRect.contains(windowPoint) else {
            scrollView.nativeMarkdownClearLinkHovers(except: nil)
            lastAppliedDecision = nil
            return
        }

        let rootView = scrollView.documentView ?? scrollView
        let hit = rootView.nativeMarkdownCursorHit(atWindowPoint: windowPoint)
        rootView.nativeMarkdownClearLinkHovers(except: hit?.hoveredTextView)
        if let textView = hit?.hoveredTextView {
            textView.nativeMarkdownSetHoveredLinkRange(hit?.hoveredLinkRange)
        }

        guard let decision = hit?.decision else {
            // Let AppKit keep its default cursor for non-markdown-interactive regions.
            if lastAppliedDecision == .pointingHand {
                NSCursor.arrow.set()
            }
            lastAppliedDecision = nil
            return
        }

        switch decision {
        case .pointingHand:
            NSCursor.pointingHand.set()
        case .textSelection:
            NSCursor.iBeam.set()
        }
        lastAppliedDecision = decision
    }
}

@MainActor
protocol NativeMarkdownPointingHandCursorRegion: AnyObject {
    func nativeMarkdownWantsPointingHandCursor(atWindowPoint windowPoint: NSPoint) -> Bool
}

private extension NSView {
    func nativeMarkdownCursorHit(atWindowPoint windowPoint: NSPoint) -> NativeMarkdownCursorCoordinator.CursorHit? {
        guard !isHidden else { return nil }
        let localPoint = convert(windowPoint, from: nil)
        guard bounds.contains(localPoint) else { return nil }

        for subview in subviews.reversed() {
            if let hit = subview.nativeMarkdownCursorHit(atWindowPoint: windowPoint) {
                return hit
            }
        }

        if let region = self as? NativeMarkdownPointingHandCursorRegion,
           region.nativeMarkdownWantsPointingHandCursor(atWindowPoint: windowPoint)
        {
            return NativeMarkdownCursorCoordinator.CursorHit(
                decision: .pointingHand,
                hoveredTextView: nil,
                hoveredLinkRange: nil
            )
        }

        if let textView = self as? NativeMarkdownSelectableTextView {
            if let linkRange = textView.nativeMarkdownLinkRange(atWindowPoint: windowPoint) {
                return NativeMarkdownCursorCoordinator.CursorHit(
                    decision: .pointingHand,
                    hoveredTextView: textView,
                    hoveredLinkRange: linkRange
                )
            }

            return NativeMarkdownCursorCoordinator.CursorHit(
                decision: .textSelection,
                hoveredTextView: nil,
                hoveredLinkRange: nil
            )
        }

        return nil
    }

    func nativeMarkdownClearLinkHovers(except retainedTextView: NativeMarkdownSelectableTextView?) {
        if let textView = self as? NativeMarkdownSelectableTextView, textView !== retainedTextView {
            textView.nativeMarkdownSetHoveredLinkRange(nil)
        }

        for subview in subviews {
            subview.nativeMarkdownClearLinkHovers(except: retainedTextView)
        }
    }
}
