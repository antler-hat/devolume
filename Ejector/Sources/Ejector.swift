import Cocoa

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var statusItem: NSStatusItem?
    private let volumeManager = VolumeManager()
    private let processRuleStore = ProcessRuleStore()
    private lazy var mainViewController = MainViewController(ruleStore: processRuleStore)
    private var rulesWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.title = "Ejector"

        window.contentViewController = mainViewController
        let preferredSize = NSSize(width: 500, height: 300)
        window.setContentSize(preferredSize)
        window.contentMinSize = preferredSize
        window.center()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupApplicationMenu()
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            if let image = NSImage(named: "iconTemplate") {
                image.isTemplate = true
                image.size = NSSize(width: 16, height: 16)
                button.image = image
            } else {
                button.title = "⏏︎"
            }
            button.toolTip = "Ejector"
            button.imageScaling = .scaleProportionallyDown
            button.controlSize = .small
        }

        let menu = NSMenu()

        let ejectAllItem = NSMenuItem(
            title: "Eject all external drives",
            action: #selector(ejectAllVolumesFromMenu),
            keyEquivalent: ""
        )
        ejectAllItem.target = self
        menu.addItem(ejectAllItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(
            title: "Open Ejector",
            action: #selector(openEjectorFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let manageRulesItem = NSMenuItem(
            title: "Manage Saved Rules…",
            action: #selector(openRulesFromMenu),
            keyEquivalent: ""
        )
        manageRulesItem.target = self
        menu.addItem(manageRulesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Ejector",
            action: #selector(quitEjectorFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    private func setupApplicationMenu() {
        // Always ensure the application has a basic menu with a quit action.
        let appName = "Ejector"
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let matchingItems = mainMenu.items.filter { $0.title == appName || $0.submenu?.title == appName }
        let appMenuItem: NSMenuItem

        if let firstMatch = matchingItems.first {
            appMenuItem = firstMatch
            matchingItems.dropFirst().forEach { mainMenu.removeItem($0) }
        } else {
            let newMenu = NSMenu(title: appName)
            let newMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
            newMenuItem.submenu = newMenu
            if mainMenu.items.isEmpty {
                mainMenu.addItem(newMenuItem)
            } else {
                mainMenu.insertItem(newMenuItem, at: 0)
            }
            appMenuItem = newMenuItem
        }

        let appMenu = appMenuItem.submenu ?? NSMenu(title: appName)
        appMenuItem.submenu = appMenu

        if appMenu.items.contains(where: { $0.action == #selector(quitEjectorFromMenu) }) {
            appMenu.items
                .first(where: { $0.action == #selector(quitEjectorFromMenu) })?
                .target = self
        } else {
            if !appMenu.items.isEmpty && !(appMenu.items.last?.isSeparatorItem ?? false) {
                appMenu.addItem(NSMenuItem.separator())
            }
            let quitItem = NSMenuItem(
                title: "Quit Ejector",
                action: #selector(quitEjectorFromMenu),
                keyEquivalent: "q"
            )
            quitItem.target = self
            appMenu.addItem(quitItem)
        }

        NSApp.mainMenu = mainMenu
    }

    private func showMainWindow() {
        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func ejectAllVolumesFromMenu(_ sender: Any?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let volumes = self.volumeManager.enumerateExternalVolumes()
            if volumes.isEmpty {
                DispatchQueue.main.async {
                    self.showMainWindow()
                    self.mainViewController.presentCompletion(
                        message: "No external drives are mounted. Nothing to eject"
                    )
                }
                return
            }

            let result = self.volumeManager.attemptEject(volumes: volumes)
            DispatchQueue.main.async {
                self.showMainWindow()
                if result.isSuccess {
                    self.mainViewController.presentCompletion(
                        message: "All external drives were ejected."
                    )
                } else {
                    self.mainViewController.presentEjectionOutcome(
                        for: volumes,
                        result: result
                    )
                }
            }
        }
    }

    @objc private func openEjectorFromMenu(_ sender: Any?) {
        let shouldRescan = !(window?.isVisible ?? false)
        showMainWindow()
        if shouldRescan {
            mainViewController.restartScan()
        }
    }

    @objc private func openRulesFromMenu(_ sender: Any?) {
        if rulesWindowController == nil {
            let controller = RulesViewController(ruleStore: processRuleStore)
            let rulesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            rulesWindow.title = "Saved Rules"
            rulesWindow.isReleasedWhenClosed = false
            rulesWindow.center()
            rulesWindow.contentViewController = controller
            rulesWindowController = NSWindowController(window: rulesWindow)
        }

        guard let controller = rulesWindowController else { return }
        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitEjectorFromMenu(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}
