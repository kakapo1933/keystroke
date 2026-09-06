import XCTest
import Cocoa
import Carbon.HIToolbox

final class FakeMonitor: KeystrokeMonitoring {
    var isRunning = false
    var succeeds = true
    var starts = 0
    var stops = 0
    func start() -> Bool {
        starts += 1
        isRunning = succeeds
        return isRunning
    }
    func stop() { stops += 1; isRunning = false }
}

final class KeystrokeTests: XCTestCase {
    var defaults: UserDefaults!
    var suite: String!
    var preferences: KeystrokePreferences!
    var model: KeystrokeViewModel!

    override func setUp() {
        suite = "com.keystroke.tests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
        preferences = KeystrokePreferences(defaults: defaults)
        model = KeystrokeViewModel(preferences: preferences)
    }
    override func tearDown() {
        model.clear()
        defaults.removePersistentDomain(forName: suite)
    }

    func testCompleteChordSurvivesNextKey() {
        model.addKeystroke(keyCode: kVK_Return, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        model.addKeystroke(keyCode: kVK_Tab, flags: [])
        XCTAssertEqual(model.recentEntries.map(\.key), ["⏎", "⇥"])
        XCTAssertEqual(model.recentEntries[0].modifiers, ["⌃", "⌥", "⇧", "⌘"])
        XCTAssertEqual(model.recentEntries[1].modifiers, [])
        preferences.showModifiers = false
        XCTAssertEqual(model.recentEntries[0].modifiers.count, 4, "Hiding modifiers must not discard data")
    }

    func testHistoryBoundAndAllPreviewSizes() {
        preferences.visibleKeyCount = 2
        ["A", "B", "C"].forEach { model.addDisplayKey($0) }
        XCTAssertEqual(model.recentEntries.map(\.key), ["B", "C"])
        for count in 1...8 {
            preferences.visibleKeyCount = count
            model.showPreview()
            XCTAssertEqual(model.entrySlots.compactMap { $0 }, KeystrokeEntry.preview(count: count))
            XCTAssertEqual(model.entrySlots.count, count)
        }
    }

    func testShortcutOnlyFiltersTextAndKeepsCommands() {
        preferences.shortcutsOnly = true
        // Filtered before layout lookup; no input-source or keyboard permissions needed.
        model.addKeystroke(keyCode: kVK_ANSI_A, flags: [], characters: "a")
        model.addKeystroke(keyCode: kVK_ANSI_A, flags: [.maskShift], characters: "A")
        model.addKeystroke(keyCode: kVK_Return, flags: [])
        model.addDisplayKey("⇪", isShortcut: false)
        XCTAssertTrue(model.recentEntries.isEmpty)
        model.addKeystroke(keyCode: kVK_Return, flags: [.maskCommand])
        model.addKeystroke(keyCode: kVK_F20, flags: [])
        XCTAssertEqual(model.recentEntries.map(\.key), ["⏎", "F20"])
        model.addDisplayKey(KeyDisplayToken.volumeUp)
        XCTAssertEqual(model.recentEntries.last?.key, KeyDisplayToken.volumeUp)
        for flags: CGEventFlags in [.maskCommand, .maskControl, .maskAlternate] {
            XCTAssertTrue(KeyMapper.isShortcut(keyCode: kVK_ANSI_A, flags: flags))
        }
        XCTAssertFalse(KeyMapper.isShortcut(keyCode: kVK_Function, flags: []))
    }

    func testFilterChangeClearsAndPersists() {
        model.addDisplayKey("old")
        preferences.shortcutsOnly = true
        XCTAssertTrue(model.recentEntries.isEmpty)
        XCTAssertTrue(KeystrokePreferences(defaults: defaults).shortcutsOnly)
        preferences.restoreDefaults()
        XCTAssertFalse(preferences.shortcutsOnly)
        XCTAssertFalse(KeystrokePreferences(defaults: defaults).shortcutsOnly)
    }

    func testPauseStopsClearsAndResumeStartsFresh() {
        let fake = FakeMonitor()
        let controller = MonitoringController(monitor: fake, viewModel: model, hasPermission: { true })
        controller.retry()
        XCTAssertEqual(controller.state, .running)
        model.addDisplayKey("old")
        controller.togglePause()
        XCTAssertEqual(controller.state, .paused)
        XCTAssertFalse(fake.isRunning)
        XCTAssertTrue(model.recentEntries.isEmpty)
        model.addDisplayKey("queued")
        model.addKeystroke(keyCode: kVK_Return, flags: [.maskCommand])
        model.showPreview()
        controller.retry()
        controller.checkHealth()
        XCTAssertTrue(model.recentEntries.isEmpty)
        XCTAssertEqual(fake.starts, 1)
        controller.togglePause()
        XCTAssertEqual(controller.state, .running)
        XCTAssertEqual(fake.starts, 2)
        XCTAssertTrue(model.recentEntries.isEmpty)
        model.addDisplayKey("new")
        XCTAssertEqual(model.recentEntries.map(\.key), ["new"])
        controller.shutdown()
        XCTAssertFalse(fake.isRunning)
    }

    func testFailedStartCanRetry() {
        let fake = FakeMonitor()
        fake.succeeds = false
        let controller = MonitoringController(monitor: fake, viewModel: model, hasPermission: { true })
        controller.retry()
        XCTAssertEqual(controller.state, .failed)
        controller.checkHealth()
        XCTAssertEqual(fake.starts, 1, "Failure should wait for explicit retry, not spin")
        fake.succeeds = true
        controller.retry()
        XCTAssertEqual(controller.state, .running)
        XCTAssertEqual(fake.starts, 2)
        controller.shutdown()
    }

    func testPermissionLossRecoveryAndPausedPermissionChange() {
        let fake = FakeMonitor()
        var permitted = false
        let controller = MonitoringController(monitor: fake, viewModel: model, hasPermission: { permitted })
        controller.retry()
        XCTAssertEqual(controller.state, .waitingForPermission)
        XCTAssertEqual(fake.starts, 0)
        permitted = true
        controller.checkHealth()
        XCTAssertEqual(controller.state, .running)
        model.addDisplayKey("old")
        permitted = false
        controller.checkHealth()
        XCTAssertFalse(fake.isRunning)
        XCTAssertTrue(model.recentEntries.isEmpty)
        XCTAssertEqual(controller.state, .waitingForPermission)
        controller.togglePause()
        permitted = true
        controller.checkHealth()
        XCTAssertEqual(controller.state, .paused)
        XCTAssertFalse(fake.isRunning)
        controller.togglePause()
        XCTAssertEqual(controller.state, .running)
        controller.shutdown()
    }

    func testDeadTapChangesStatusAndClears() {
        let fake = FakeMonitor()
        let controller = MonitoringController(monitor: fake, viewModel: model, hasPermission: { true })
        controller.retry()
        model.addDisplayKey("old")
        fake.isRunning = false
        controller.checkHealth()
        XCTAssertEqual(controller.state, .failed)
        XCTAssertTrue(model.recentEntries.isEmpty)
    }

    func testFadeResetsOnNewInputAndPauseCancelsOldFade() {
        preferences.fadeDelay = 0.5
        model.addDisplayKey("A")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        model.addDisplayKey("B")
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(model.recentEntries.map(\.key), ["A", "B"])
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(model.recentEntries.isEmpty)
        model.addDisplayKey("before-pause")
        model.setPaused(true)
        model.setPaused(false)
        preferences.fadeDelay = 6
        model.addDisplayKey("after-resume")
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        XCTAssertEqual(model.recentEntries.map(\.key), ["after-resume"])
    }

    func testPreferenceClampingAndPositionPersistence() {
        preferences.visibleKeyCount = 100
        preferences.keySize = 1
        preferences.keyBackgroundOpacity = 2
        preferences.fadeDelay = 100
        preferences.saveOverlayOrigin(CGPoint(x: -200, y: 100))
        let reloaded = KeystrokePreferences(defaults: defaults)
        XCTAssertEqual(reloaded.visibleKeyCount, 8)
        XCTAssertEqual(reloaded.keySize, 40)
        XCTAssertEqual(reloaded.keyBackgroundOpacity, 1)
        XCTAssertEqual(reloaded.fadeDelay, 6)
        XCTAssertEqual(reloaded.savedOverlayOrigin, CGPoint(x: -200, y: 100))
        preferences.clearOverlayOrigin()
        XCTAssertNil(KeystrokePreferences(defaults: defaults).savedOverlayOrigin)
    }
}

let suite = KeystrokeTests.defaultTestSuite
suite.run()
guard let result = suite.testRun, result.executionCount > 0, result.hasSucceeded else { exit(1) }
