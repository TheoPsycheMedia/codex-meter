import AppKit
import SwiftUI

@MainActor
final class WidgetWindowController {
    private let store: WidgetStore
    private let panel: FloatingWidgetPanel
    private let defaultPanelSize = NSSize(width: 440, height: 780)
    private let minimumPanelSize = NSSize(width: 390, height: 540)

    init(store: WidgetStore) {
        self.store = store
        self.panel = FloatingWidgetPanel(
            contentRect: NSRect(origin: .zero, size: defaultPanelSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureContent()
        snapToTopRight(animated: false)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func snapToTopRight(animated: Bool) {
        let currentSize = panel.frame.size
        let targetSize = currentSize.width > 0 && currentSize.height > 0 ? currentSize : defaultPanelSize
        let frame = ScreenPlacement.topRightFrame(size: targetSize, margin: 18)
        panel.setFrame(frame, display: true, animate: animated)
    }

    func resetPositionAndSize(animated: Bool) {
        let frame = ScreenPlacement.topRightFrame(size: defaultPanelSize, margin: 18)
        panel.setFrame(frame, display: true, animate: animated)
    }

    private func configurePanel() {
        panel.title = L10n.text("app.name")
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.minSize = minimumPanelSize
        panel.contentMinSize = minimumPanelSize
        panel.isMovableByWindowBackground = false
    }

    private func configureContent() {
        let view = MeterWidgetView(
            store: store,
            onHide: { [weak self] in self?.hide() },
            onSnap: { [weak self] in self?.resetPositionAndSize(animated: true) }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: defaultPanelSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }
}
