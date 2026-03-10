import Carbon.HIToolbox
import CoreGraphics

enum KeyMapper {

    // MARK: - Modifier symbols (standard macOS order: ⌃⌥⇧⌘)

    static func modifierSymbols(for flags: CGEventFlags) -> String {
        var symbols = ""
        if flags.contains(.maskControl)   { symbols += "⌃" }
        if flags.contains(.maskAlternate)  { symbols += "⌥" }
        if flags.contains(.maskShift)      { symbols += "⇧" }
        if flags.contains(.maskCommand)    { symbols += "⌘" }
        return symbols
    }

    // MARK: - Key name from keycode

    static func keyName(for keyCode: Int) -> String {
        if let special = specialKeys[keyCode] {
            return special
        }
        if let alpha = alphanumericKeys[keyCode] {
            return alpha
        }
        return "?"
    }

    static func isSpecialKey(_ keyCode: Int) -> Bool {
        specialKeys[keyCode] != nil
    }

    /// Translate keyCode using the CURRENT keyboard layout via UCKeyTranslate.
    /// Fixes stale input source issue after switching input methods.
    /// Translate keyCode using the CURRENT keyboard layout via UCKeyTranslate.
    static func currentLayoutCharacter(keyCode: Int, shift: Bool, capsLock: Bool = false) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        guard let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        guard let bytePtr = CFDataGetBytePtr(layoutData) else { return nil }
        let dataLength = CFDataGetLength(layoutData)

        var modState: UInt32 = 0
        if shift    { modState |= 2 }  // shiftKey >> 8
        if capsLock { modState |= 4 }  // alphaLockKey >> 8

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength: Int = 0

        let status = bytePtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: dataLength) { keyboardLayout in
            UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                modState,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &actualLength,
                &chars
            )
        }

        guard status == noErr, actualLength > 0 else { return nil }
        let result = String(utf16CodeUnits: chars, count: actualLength)
        guard let scalar = result.unicodeScalars.first, scalar.value >= 32, scalar.value != 127 else {
            return nil
        }
        return result
    }

    static func displayText(keyCode: Int, flags: CGEventFlags, characters: String?) -> (modifiers: String, key: String) {
        let hasShift = flags.contains(.maskShift)
        let hasCmd   = flags.contains(.maskCommand)
        let hasCtrl  = flags.contains(.maskControl)
        let hasOpt   = flags.contains(.maskAlternate)
        let hasOtherModifiers = hasCmd || hasCtrl || hasOpt

        // Special keys: show all modifiers + symbol
        if isSpecialKey(keyCode) {
            return (modifierSymbols(for: flags), keyName(for: keyCode))
        }

        // Build modifier string:
        // Shift-only → reflected in character case, don't show ⇧
        // Shift + others → show ⇧ as symbol
        var modifiers = ""
        if hasCtrl  { modifiers += "⌃" }
        if hasOpt   { modifiers += "⌥" }
        if hasShift && hasOtherModifiers { modifiers += "⇧" }
        if hasCmd   { modifiers += "⌘" }

        // Get character with shift/capsLock applied for correct case
        let hasCapsLock = flags.contains(.maskAlphaShift)
        let key: String
        if let layoutChar = currentLayoutCharacter(keyCode: keyCode, shift: hasShift, capsLock: hasCapsLock), !layoutChar.isEmpty {
            key = layoutChar
        } else if let chars = characters,
                  !chars.isEmpty,
                  chars.unicodeScalars.first.map({ $0.value >= 32 && $0.value != 127 }) == true {
            key = chars
        } else {
            key = keyName(for: keyCode)
        }

        return (modifiers, key)
    }

    // MARK: - Special keys

    private static let specialKeys: [Int: String] = [
        kVK_Return:         "⏎",
        kVK_Tab:            "⇥",
        kVK_Space:          "␣",
        kVK_Delete:         "⌫",
        kVK_ForwardDelete:  "⌦",
        kVK_Escape:         "⎋",
        kVK_CapsLock:       "⇪",

        kVK_LeftArrow:      "←",
        kVK_RightArrow:     "→",
        kVK_UpArrow:        "↑",
        kVK_DownArrow:      "↓",

        kVK_Home:           "↖",
        kVK_End:            "↘",
        kVK_PageUp:         "⇞",
        kVK_PageDown:       "⇟",

        kVK_F1:  "F1",  kVK_F2:  "F2",  kVK_F3:  "F3",  kVK_F4:  "F4",
        kVK_F5:  "F5",  kVK_F6:  "F6",  kVK_F7:  "F7",  kVK_F8:  "F8",
        kVK_F9:  "F9",  kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
        kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",

        kVK_ANSI_KeypadEnter:    "⌤",
        kVK_ANSI_KeypadClear:    "⌧",
        kVK_ANSI_KeypadEquals:   "=",
        kVK_ANSI_KeypadMultiply: "×",
        kVK_ANSI_KeypadPlus:     "+",
        kVK_ANSI_KeypadMinus:    "-",
        kVK_ANSI_KeypadDivide:   "÷",
        kVK_ANSI_KeypadDecimal:  ".",
        kVK_ANSI_Keypad0: "0",  kVK_ANSI_Keypad1: "1",
        kVK_ANSI_Keypad2: "2",  kVK_ANSI_Keypad3: "3",
        kVK_ANSI_Keypad4: "4",  kVK_ANSI_Keypad5: "5",
        kVK_ANSI_Keypad6: "6",  kVK_ANSI_Keypad7: "7",
        kVK_ANSI_Keypad8: "8",  kVK_ANSI_Keypad9: "9",
    ]

    // MARK: - Alphanumeric / punctuation keys

    private static let alphanumericKeys: [Int: String] = [
        kVK_ANSI_A: "A",  kVK_ANSI_B: "B",  kVK_ANSI_C: "C",
        kVK_ANSI_D: "D",  kVK_ANSI_E: "E",  kVK_ANSI_F: "F",
        kVK_ANSI_G: "G",  kVK_ANSI_H: "H",  kVK_ANSI_I: "I",
        kVK_ANSI_J: "J",  kVK_ANSI_K: "K",  kVK_ANSI_L: "L",
        kVK_ANSI_M: "M",  kVK_ANSI_N: "N",  kVK_ANSI_O: "O",
        kVK_ANSI_P: "P",  kVK_ANSI_Q: "Q",  kVK_ANSI_R: "R",
        kVK_ANSI_S: "S",  kVK_ANSI_T: "T",  kVK_ANSI_U: "U",
        kVK_ANSI_V: "V",  kVK_ANSI_W: "W",  kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y",  kVK_ANSI_Z: "Z",

        kVK_ANSI_0: "0",  kVK_ANSI_1: "1",  kVK_ANSI_2: "2",
        kVK_ANSI_3: "3",  kVK_ANSI_4: "4",  kVK_ANSI_5: "5",
        kVK_ANSI_6: "6",  kVK_ANSI_7: "7",  kVK_ANSI_8: "8",
        kVK_ANSI_9: "9",

        kVK_ANSI_Minus:        "-",
        kVK_ANSI_Equal:        "=",
        kVK_ANSI_LeftBracket:  "[",
        kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash:    "\\",
        kVK_ANSI_Semicolon:    ";",
        kVK_ANSI_Quote:        "'",
        kVK_ANSI_Comma:        ",",
        kVK_ANSI_Period:       ".",
        kVK_ANSI_Slash:        "/",
        kVK_ANSI_Grave:        "`",
    ]
}
