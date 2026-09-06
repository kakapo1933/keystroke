import Foundation

/// One complete input event. Modifiers belong to this entry, not to the history strip.
struct KeystrokeEntry: Equatable {
    let key: String
    var modifiers: [String] = []
    var isShortcut = false

    static func preview(count: Int) -> [KeystrokeEntry] {
        let samples = [
            KeystrokeEntry(key: "⏎", modifiers: ["⌃", "⌥", "⇧", "⌘"], isShortcut: true),
            KeystrokeEntry(key: "C", modifiers: ["⌘"], isShortcut: true),
            KeystrokeEntry(key: "V", modifiers: ["⌘"], isShortcut: true),
            KeystrokeEntry(key: "F5", isShortcut: true),
            KeystrokeEntry(key: KeyDisplayToken.volumeDown, isShortcut: true),
            KeystrokeEntry(key: KeyDisplayToken.volumeUp, isShortcut: true),
            KeystrokeEntry(key: KeyDisplayToken.playPause, isShortcut: true),
            KeystrokeEntry(key: KeyDisplayToken.nextTrack, isShortcut: true)
        ]
        return Array(samples.prefix(count))
    }
}
