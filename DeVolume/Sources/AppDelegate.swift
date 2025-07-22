import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var volumesController: VolumesViewController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        setupMenu()
        
        // Create the main window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Volume Process Manager"
        
        // Create and set the volumes view controller
        volumesController = VolumesViewController()
        window.contentViewController = volumesController
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
private func setupMenu() {
    let mainMenu = NSMenu()
    NSApp.mainMenu = mainMenu

    // Application menu
    let appMenu = NSMenu()
    let appMenuItem = NSMenuItem(title: "DeVolume", action: nil, keyEquivalent: "")
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Add Quit item
    appMenu.addItem(NSMenuItem(title: "Quit DeVolume",
                               action: #selector(NSApplication.terminate(_:)),
                               keyEquivalent: "q"))
}
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
