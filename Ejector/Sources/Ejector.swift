import Cocoa
import DiskArbitration

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the main window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Ejector"

        // Set MainViewController as the root view controller
        window.contentViewController = MainViewController()
        let preferredSize = NSSize(width: 500, height: 300)
        window.setContentSize(preferredSize)
        window.contentMinSize = preferredSize
        window.center()

        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
