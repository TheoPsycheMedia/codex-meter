import AppKit
import SwiftUI

@MainActor
final class StatusPopoverController {
    private let store: WidgetStore
    private let panel: StatusPopoverPanel
    private let panelSize = NSSize(width: 318, height: 348)
    private let widgetButtonTitle: () -> String
    private let onRefresh: () -> Void
    private let onToggleWidget: () -> Void
    private let onSettings: () -> Void
    private var dismissalMonitor: Any?

    init(
        store: WidgetStore,
        widgetButtonTitle: @escaping () -> String,
        onRefresh: @escaping () -> Void,
        onToggleWidget: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.store = store
        self.widgetButtonTitle = widgetButtonTitle
        self.onRefresh = onRefresh
        self.onToggleWidget = onToggleWidget
        self.onSettings = onSettings

        self.panel = StatusPopoverPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    var isShown: Bool {
        panel.isVisible
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func close() {
        panel.orderOut(nil)
        removeDismissalMonitor()
    }

    private func show(relativeTo button: NSStatusBarButton) {
        let hostingView = NSHostingView(
            rootView: StatusPopoverView(
                store: store,
                widgetButtonTitle: widgetButtonTitle(),
                onRefresh: onRefresh,
                onToggleWidget: { [weak self] in
                    self?.close()
                    self?.onToggleWidget()
                },
                onSettings: { [weak self] in
                    self?.close()
                    self?.onSettings()
                }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = hostingView
        panel.setContentSize(panelSize)
        panel.setFrameOrigin(origin(for: panelSize, relativeTo: button))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installDismissalMonitor()
    }

    private func configurePanel() {
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
    }

    private func origin(for size: NSSize, relativeTo button: NSStatusBarButton) -> NSPoint {
        guard let buttonWindow = button.window else {
            let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            return NSPoint(
                x: visibleFrame.maxX - size.width - 12,
                y: visibleFrame.maxY - size.height - 12
            )
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let screen = buttonWindow.screen ?? NSScreen.screens.first { $0.frame.intersects(screenRect) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 8
        let gapBelowMenuBar: CGFloat = 12
        let rawX = screenRect.midX - (size.width / 2)
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - size.width - margin
        let topY = min(screenRect.minY, visibleFrame.maxY) - gapBelowMenuBar

        return NSPoint(
            x: min(max(rawX, minX), maxX),
            y: max(visibleFrame.minY + margin, topY - size.height)
        )
    }

    private func installDismissalMonitor() {
        removeDismissalMonitor()
        dismissalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
    }

    private func removeDismissalMonitor() {
        if let dismissalMonitor {
            NSEvent.removeMonitor(dismissalMonitor)
            self.dismissalMonitor = nil
        }
    }
}

@MainActor
private final class StatusPopoverPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
