import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let store: WidgetStore
    private let launchAtLoginService: LaunchAtLoginService
    private let window: NSWindow

    init(store: WidgetStore, launchAtLoginService: LaunchAtLoginService) {
        self.store = store
        self.launchAtLoginService = launchAtLoginService
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureWindow() {
        window.title = "Codex Meter Settings"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(
            rootView: SettingsView(
                store: store,
                launchAtLoginService: launchAtLoginService
            )
        )
    }
}
