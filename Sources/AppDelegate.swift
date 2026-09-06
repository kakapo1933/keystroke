import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleOverlayItem: NSMenuItem!
    private var lockItem: NSMenuItem!
    private var overlayPanel: OverlayPanel!
    private var monitoring: MonitoringController!
    private var monitoringItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var retryItem: NSMenuItem!
    private var previewItem: NSMenuItem!
    private var cancellables = Set<AnyCancellable>()
    private var viewModel: KeystrokeViewModel!
    private var preferences: KeystrokePreferences!
    private var settingsWindow: NSWindow?
    private var isVisible = true
    private var isLocked = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.lifecycle.notice("App launched")
        preferences = KeystrokePreferences()
        viewModel = KeystrokeViewModel(preferences: preferences)
        monitoring = MonitoringController(monitor: KeystrokeMonitor(viewModel: viewModel), viewModel: viewModel)
        overlayPanel = OverlayPanel(viewModel: viewModel, preferences: preferences)
        setupStatusBar()
        monitoring.$state.sink { [weak self] state in self?.updateMonitoringMenu(state) }
            .store(in: &cancellables)
        monitoring.start()
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
        }
        if ProcessInfo.processInfo.arguments.contains("--settings") {
            showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitoring.shutdown()
        AppLog.lifecycle.notice("App terminating")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    private func updateMonitoringMenu(_ state: MonitoringController.State) {
        monitoringItem.title = state.title
        pauseItem.title = state == .paused ? "繼續監聽" : "暫停監聽"
        retryItem.isHidden = state == .running || state == .paused
        previewItem.isEnabled = state != .paused
        statusItem.button?.toolTip = "KeyStroke — " + state.title
    }

    @objc private func togglePause(_ sender: NSMenuItem) { monitoring.togglePause() }
    @objc private func retryMonitoring(_ sender: NSMenuItem) { monitoring.retry() }

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
        menu.autoenablesItems = false
        monitoringItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        monitoringItem.isEnabled = false
        menu.addItem(monitoringItem)
        pauseItem = NSMenuItem(title: "暫停監聽", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pauseItem)
        retryItem = NSMenuItem(title: "重試監聽", action: #selector(retryMonitoring), keyEquivalent: "")
        menu.addItem(retryItem)
        menu.addItem(.separator())

        toggleOverlayItem = NSMenuItem(
            title: "隱藏浮層",
            action: #selector(toggleOverlay),
            keyEquivalent: "h"
        )
        menu.addItem(toggleOverlayItem)

        lockItem = NSMenuItem(
            title: "解鎖位置",
            action: #selector(toggleLock),
            keyEquivalent: "l"
        )
        menu.addItem(lockItem)

        menu.addItem(NSMenuItem.separator())

        previewItem = NSMenuItem(title: "預覽按鍵", action: #selector(previewKeys), keyEquivalent: "p")
        menu.addItem(previewItem)

        menu.addItem(NSMenuItem(
            title: "重設位置",
            action: #selector(resetPosition),
            keyEquivalent: "r"
        ))

        menu.addItem(NSMenuItem(
            title: "設定⋯",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem(
            title: "輔助使用權限⋯",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "結束 KeyStroke",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    @objc private func toggleOverlay(_ sender: NSMenuItem) {
        isVisible.toggle()
        if isVisible {
            overlayPanel.orderFrontRegardless()
            sender.title = "隱藏浮層"
        } else {
            overlayPanel.orderOut(nil)
            sender.title = "顯示浮層"
        }
    }

    @objc private func toggleLock(_ sender: NSMenuItem) {
        isLocked.toggle()
        overlayPanel.setLocked(isLocked)
        sender.title = isLocked ? "解鎖位置" : "鎖定位置"
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
                monitoring: monitoring,
                openPermissions: { [weak self] in self?.openAccessibilitySettings(NSMenuItem()) },
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
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "KeyStroke 設定"
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
        toggleOverlayItem.title = "隱藏浮層"
    }
}
