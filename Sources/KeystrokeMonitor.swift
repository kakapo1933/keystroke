import Cocoa
import Carbon.HIToolbox

class KeystrokeMonitor {
    private let systemDefinedEventTypeRawValue: UInt32 = 14
    private let mediaKeyDuplicateWindow: TimeInterval = 0.15
    private let viewModel: KeystrokeViewModel
    private let mediaKeyLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var systemDefinedMonitor: Any?
    private var lastMediaKey: String?
    private var lastMediaKeyTime = Date.distantPast

    init(viewModel: KeystrokeViewModel) {
        self.viewModel = viewModel
    }

    func start() {
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

                DispatchQueue.main.async {
                    monitor.viewModel.addDisplayKey(KeyMapper.keyName(for: keyCode))
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

            // Extract Unicode string from event (supports CJK / IME input)
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
            DispatchQueue.main.async {
                monitor.viewModel.addKeystroke(keyCode: kc, flags: fl, characters: ch)
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
            print("❌ Failed to create event tap.")
            print("   Grant Accessibility access in System Settings → Privacy & Security → Accessibility")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        startSystemDefinedMonitor()
        print("✅ Keystroke monitoring started")
    }

    func stop() {
        if let monitor = systemDefinedMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        systemDefinedMonitor = nil
        eventTap = nil
        runLoopSource = nil
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

        DispatchQueue.main.async { [weak self] in
            self?.viewModel.addDisplayKey(mediaKey)
        }
    }
}
