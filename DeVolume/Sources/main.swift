import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

// Start the application
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
