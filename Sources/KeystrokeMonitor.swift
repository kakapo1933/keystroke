import Cocoa
import Carbon.HIToolbox

final class KeystrokeMonitor: KeystrokeMonitoring {
    private let systemDefinedEventTypeRawValue: UInt32 = 14
    private let mediaKeyDuplicateWindow: TimeInterval = 0.15
    private let viewModel: KeystrokeViewModel
    private let mediaKeyLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var systemDefinedMonitor: Any?
    private var generation = 0
    private var lastMediaKey: String?
    private var lastMediaKeyTime = Date.distantPast

    init(viewModel: KeystrokeViewModel) {
        self.viewModel = viewModel
    }

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CFMachPortIsValid(eventTap) && CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() -> Bool {
        if isRunning { return true }
        stop()

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << systemDefinedEventTypeRawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(userInfo).takeUnretainedValue()

            // Re-enable tap if it was disabled
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if type == .flagsChanged {
                let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                guard keyCode == kVK_CapsLock else {
                    return Unmanaged.passUnretained(event)
                }

                monitor.enqueue { model in
                    model.addDisplayKey(KeyMapper.keyName(for: keyCode), isShortcut: false)
                }
                return Unmanaged.passUnretained(event)
            }

            if type.rawValue == monitor.systemDefinedEventTypeRawValue {
                guard let mediaKey = KeyMapper.mediaKeyName(from: event) else {
                    return Unmanaged.passUnretained(event)
                }

                monitor.showMediaKey(mediaKey)
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Event text is a fallback; layout translation is resolved by KeyMapper.
            var actualLength: Int = 0
            var chars = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(
                maxStringLength: 4,
                actualStringLength: &actualLength,
                unicodeString: &chars
            )
            let characters: String? = actualLength > 0
                ? String(utf16CodeUnits: chars, count: actualLength)
                : nil

            let kc = Int(keyCode)
            let fl = flags
            let ch = characters
            guard KeyMapper.canDisplayKeyDown(keyCode: kc, characters: ch) else {
                return Unmanaged.passUnretained(event)
            }
            monitor.enqueue { model in
                model.addKeystroke(keyCode: kc, flags: fl, characters: ch)
            }

            return Unmanaged.passUnretained(event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            AppLog.lifecycle.error("Failed to create keyboard event tap")
            return false
        }

        self.eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            stop()
            AppLog.lifecycle.error("Failed to create keyboard run loop source")
            return false
        }
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard isRunning else {
            stop()
            AppLog.lifecycle.error("Keyboard event tap could not be enabled")
            return false
        }
        startSystemDefinedMonitor()
        AppLog.lifecycle.info("Keyboard event tap started")
        return true
    }

    func stop() {
        generation += 1
        if let monitor = systemDefinedMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        systemDefinedMonitor = nil
        eventTap = nil
        runLoopSource = nil
        lastMediaKey = nil
        lastMediaKeyTime = .distantPast
    }

    private func enqueue(_ deliver: @escaping (KeystrokeViewModel) -> Void) {
        let currentGeneration = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == currentGeneration, self.isRunning else { return }
            deliver(self.viewModel)
        }
    }

    private func startSystemDefinedMonitor() {
        systemDefinedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self, let mediaKey = KeyMapper.mediaKeyName(from: event) else { return }
            self.showMediaKey(mediaKey)
        }
    }

    private func showMediaKey(_ mediaKey: String) {
        let now = Date()

        mediaKeyLock.lock()
        let isDuplicate = mediaKey == lastMediaKey && now.timeIntervalSince(lastMediaKeyTime) < mediaKeyDuplicateWindow
        if !isDuplicate {
            lastMediaKey = mediaKey
            lastMediaKeyTime = now
        }
        mediaKeyLock.unlock()

        guard !isDuplicate else { return }

        enqueue { $0.addDisplayKey(mediaKey) }
    }
}
