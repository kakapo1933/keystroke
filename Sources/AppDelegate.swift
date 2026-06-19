import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleOverlayItem: NSMenuItem!
    private var lockItem: NSMenuItem!
    private var overlayPanel: OverlayPanel!
    private var monitor: KeystrokeMonitor!
    private var viewModel: KeystrokeViewModel!
    private var preferences: KeystrokePreferences!
    private var settingsWindow: NSWindow?
    private var isVisible = true
    private var isLocked = true

    private let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/keystroke/keystroke.log")

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            try? FileManager.default.createDirectory(
                at: logFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
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

        preferences = KeystrokePreferences()
        viewModel = KeystrokeViewModel(preferences: preferences)
        overlayPanel = OverlayPanel(viewModel: viewModel, preferences: preferences)
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

        toggleOverlayItem = NSMenuItem(
            title: "Hide Overlay",
            action: #selector(toggleOverlay),
            keyEquivalent: "h"
        )
        menu.addItem(toggleOverlayItem)

        lockItem = NSMenuItem(
            title: "Unlock Position",
            action: #selector(toggleLock),
            keyEquivalent: "l"
        )
        menu.addItem(lockItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Preview Keys",
            action: #selector(previewKeys),
            keyEquivalent: "p"
        ))

        menu.addItem(NSMenuItem(
            title: "Reset Position",
            action: #selector(resetPosition),
            keyEquivalent: "r"
        ))

        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem(
            title: "Accessibility...",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ))

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

    @objc private func openSettings(_ sender: NSMenuItem) {
        showSettingsWindow()
    }

    @objc private func previewKeys(_ sender: NSMenuItem) {
        showOverlayIfNeeded()
        viewModel.showPreview()
    }

    @objc private func resetPosition(_ sender: NSMenuItem) {
        showOverlayIfNeeded()
        overlayPanel.resetPosition()
    }

    @objc private func openAccessibilitySettings(_ sender: NSMenuItem) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func showSettingsWindow() {
        if settingsWindow == nil {
            let rootView = SettingsView(
                preferences: preferences,
                preview: { [weak self] in
                    self?.showOverlayIfNeeded()
                    self?.viewModel.showPreview()
                },
                resetPosition: { [weak self] in
                    self?.showOverlayIfNeeded()
                    self?.overlayPanel.resetPosition()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "KeyStroke Settings"
            window.contentView = NSHostingView(rootView: rootView)
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("KeyStrokeSettings")
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOverlayIfNeeded() {
        guard !isVisible else { return }
        isVisible = true
        overlayPanel.orderFrontRegardless()
        toggleOverlayItem.title = "Hide Overlay"
    }
}
