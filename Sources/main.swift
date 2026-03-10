import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApp.setActivationPolicy(.accessory)  // No dock icon
NSApp.run()
