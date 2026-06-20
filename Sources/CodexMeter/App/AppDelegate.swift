import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = WidgetStore()
    private let launchAtLoginService = LaunchAtLoginService()
    private var widgetController: WidgetWindowController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = WidgetWindowController(store: store)
        widgetController = controller
        settingsController = SettingsWindowController(
            store: store,
            launchAtLoginService: launchAtLoginService
        )

        launchAtLoginService.refresh()
        if launchAtLoginService.isEnabled || launchAtLoginService.requiresApproval {
            store.launchAtLoginEnabled = true
        }

        configureStatusItem()
        configureStatusItemBindings()
        configureAutoRefresh()

        if shouldShowWidgetOnStartup() {
            controller.show()
        }

        Task {
            await store.refresh()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        store.save()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = StatusItemIcon.image()
        item.button?.imagePosition = .imageLeft
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        updateStatusItem()
    }

    private func configureStatusItemBindings() {
        store.$statusItemDisplayMode.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$showSparkUsage.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$usage.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$isLoading.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$usageRefreshState.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$resetCreditRefreshState.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$lastUpdated.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)

        launchAtLoginService.$status
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }

    private func shouldShowWidgetOnStartup() -> Bool {
        if store.launchAtLoginEnabled {
            if launchAtLoginService.isEnabled || launchAtLoginService.requiresApproval {
                return false
            }
        }

        return true
    }

    private func statusSnapshot() -> StatusItemSnapshot {
        StatusItemSnapshot(
            usage: store.usage,
            showSparkUsage: store.showSparkUsage,
            mode: store.statusItemDisplayMode,
            isLoading: store.isLoading,
            errorMessage: store.primaryFailure?.message,
            lastUpdated: store.lastUpdated,
            staleAfterSeconds: store.statusItemStaleAfterSeconds
        )
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        let snapshot = statusSnapshot()

        if snapshot.mode.isIconOnly {
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.imagePosition = .imageLeft
            button.title = snapshot.statusText
        }

        button.toolTip = snapshot.tooltipText
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let snapshot = statusSnapshot()

        menu.addItem(makeStaticMenuItem("Launch-at-login: \(launchAtLoginService.displaySummary)"))

        if launchAtLoginService.requiresApproval {
            let approvalItem = NSMenuItem(title: "Open Login Items...", action: #selector(openLoginItems), keyEquivalent: "")
            approvalItem.target = self
            menu.addItem(approvalItem)
        }

        menu.addItem(.separator())
        menu.addItem(makeStaticMenuItem(snapshot.menuActionSummary))

        if snapshot.hasWindowData {
            if let lastUpdated = snapshot.lastUpdated {
                menu.addItem(makeStaticMenuItem("Last updated: \(Self.timeFormatter.string(from: lastUpdated))"))
            }

            if snapshot.isStale {
                menu.addItem(makeStaticMenuItem("Warning: data may be stale"))
            }

            menu.addItem(.separator())
            menu.addItem(makeStaticMenuItem("Usage breakdown"))
            for row in snapshot.menuRows {
                menu.addItem(makeStaticMenuItem(row))
            }
        } else if snapshot.errorMessage != nil {
            let errorMessage = snapshot.errorMessage ?? "Unable to load usage"
            menu.addItem(makeStaticMenuItem("Error: \(errorMessage)"))
        } else {
            menu.addItem(makeStaticMenuItem(snapshot.isLoading ? "Loading usage data" : "No usage data yet"))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshCredits), keyEquivalent: "r"))

        let displayModeItem = NSMenuItem(title: "Menu-Bar Display", action: nil, keyEquivalent: "")
        let displayModeMenu = NSMenu()
        for mode in StatusItemDisplayMode.allCases {
            let modeItem = NSMenuItem(
                title: "\(mode.title) (\(snapshot.previewText(for: mode)))",
                action: #selector(setStatusItemDisplayMode(_:)),
                keyEquivalent: ""
            )
            modeItem.target = self
            modeItem.representedObject = mode.rawValue
            modeItem.state = mode == store.statusItemDisplayMode ? .on : .off
            displayModeMenu.addItem(modeItem)
        }
        displayModeItem.submenu = displayModeMenu
        menu.addItem(displayModeItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: widgetController?.isVisible == true ? "Hide Codex Meter" : "Show Codex Meter",
            action: #selector(toggleWidget),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(title: "Reset Position and Size", action: #selector(resetWidgetPlacement), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Codex Meter", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            if item.submenu == nil {
                item.target = self
            }
        }

        return menu
    }

    private func makeStaticMenuItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func configureAutoRefresh() {
        store.$autoRefreshEnabled
            .combineLatest(store.$refreshIntervalSeconds)
            .sink { [weak self] _, _ in
                self?.restartRefreshTimer()
            }
            .store(in: &cancellables)

        restartRefreshTimer()
    }

    private func restartRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        guard store.autoRefreshEnabled else {
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: store.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.store.refresh()
            }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            toggleWidget()
        }
    }

    @objc private func toggleWidget() {
        if widgetController?.isVisible == true {
            hideWidget()
        } else {
            showWidget()
        }
    }

    @objc private func showWidget() {
        widgetController?.show()
        Task {
            await store.refreshIfStale()
        }
    }

    @objc private func refreshCredits() {
        widgetController?.show()
        Task {
            await store.refresh()
        }
    }

    @objc private func setStatusItemDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = StatusItemDisplayMode(rawValue: rawValue)
        else {
            return
        }

        store.statusItemDisplayMode = mode
        updateStatusItem()
    }

    @objc private func openLoginItems() {
        launchAtLoginService.openLoginItemsSettings()
    }

    @objc private func hideWidget() {
        widgetController?.hide()
    }

    @objc private func snapWidget() {
        widgetController?.snapToTopRight(animated: true)
    }

    @objc private func resetWidgetPlacement() {
        widgetController?.resetPositionAndSize(animated: true)
    }

    @objc private func showSettings() {
        settingsController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func screenParametersChanged() {
        widgetController?.snapToTopRight(animated: true)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
