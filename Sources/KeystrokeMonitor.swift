import Cocoa

class KeystrokeMonitor {
    private let viewModel: KeystrokeViewModel
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(viewModel: KeystrokeViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

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
        print("✅ Keystroke monitoring started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
