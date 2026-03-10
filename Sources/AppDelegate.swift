import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayPanel: OverlayPanel!
    private var monitor: KeystrokeMonitor!
    private var viewModel: KeystrokeViewModel!
    private var isVisible = true
    private var isLocked = true

    private let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/keystroke/keystroke.log")

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("App launched")

        viewModel = KeystrokeViewModel()
        overlayPanel = OverlayPanel(viewModel: viewModel)
        setupStatusBar()

        let trusted = AXIsProcessTrusted()
        log("AXIsProcessTrusted: \(trusted)")

        if trusted {
            startMonitoring()
        } else {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            log("Prompted for accessibility, starting poll...")
            pollForAccessibility()
        }
    }

    private func startMonitoring() {
        guard monitor == nil else { return }
        log("Starting keystroke monitor...")
        monitor = KeystrokeMonitor(viewModel: viewModel)
        monitor.start()
        log("Monitor started")
    }

    private func pollForAccessibility() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            let trusted = AXIsProcessTrusted()
            self?.log("Poll: AXIsProcessTrusted = \(trusted)")
            if trusted {
                timer.invalidate()
                self?.startMonitoring()
            }
        }
    }

    // MARK: - Menu Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "KeyStroke"
            )
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Hide Overlay",
            action: #selector(toggleOverlay),
            keyEquivalent: "h"
        )
        menu.addItem(toggleItem)

        let lockItem = NSMenuItem(
            title: "Unlock Position",
            action: #selector(toggleLock),
            keyEquivalent: "l"
        )
        menu.addItem(lockItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit KeyStroke",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    @objc private func toggleOverlay(_ sender: NSMenuItem) {
        isVisible.toggle()
        if isVisible {
            overlayPanel.orderFrontRegardless()
            sender.title = "Hide Overlay"
        } else {
            overlayPanel.orderOut(nil)
            sender.title = "Show Overlay"
        }
    }

    @objc private func toggleLock(_ sender: NSMenuItem) {
        isLocked.toggle()
        overlayPanel.setLocked(isLocked)
        sender.title = isLocked ? "Unlock Position" : "Lock Position"
    }
}
