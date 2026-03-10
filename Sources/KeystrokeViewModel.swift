import SwiftUI
import Combine

struct KeystrokeEntry: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var timestamp: Date
    var isCombo: Bool

    static func == (lhs: KeystrokeEntry, rhs: KeystrokeEntry) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text
    }
}

class KeystrokeViewModel: ObservableObject {
    @Published var entries: [KeystrokeEntry] = []
    @Published var isEditing: Bool = false

    private let maxEntries = 5
    private let fadeDelay: TimeInterval = 2.0
    private let combineThreshold: TimeInterval = 0.5

    func addKeystroke(keyCode: Int, flags: CGEventFlags, characters: String? = nil) {
        let (modifiers, key) = KeyMapper.displayText(keyCode: keyCode, flags: flags, characters: characters)

        let hasModifiers = !modifiers.isEmpty
        let displayText = hasModifiers ? "\(modifiers) \(key)" : key

        let now = Date()

        // Combine rapid sequential keystrokes without modifiers
        if !hasModifiers,
           !entries.isEmpty,
           !entries[entries.count - 1].isCombo,
           now.timeIntervalSince(entries[entries.count - 1].timestamp) < combineThreshold {
            entries[entries.count - 1].text += key
            entries[entries.count - 1].timestamp = now
            scheduleFadeout(for: entries[entries.count - 1].id)
            return
        }

        let entry = KeystrokeEntry(text: displayText, timestamp: now, isCombo: hasModifiers)
        entries.append(entry)

        // Trim old entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        scheduleFadeout(for: entry.id)
    }

    private func scheduleFadeout(for id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) { [weak self] in
            guard let self = self else { return }
            guard let index = self.entries.firstIndex(where: { $0.id == id }) else { return }

            let elapsed = Date().timeIntervalSince(self.entries[index].timestamp)
            if elapsed >= self.fadeDelay - 0.1 {
                _ = withAnimation(.easeOut(duration: 0.3)) {
                    self.entries.remove(at: index)
                }
            } else {
                let remaining = self.fadeDelay - elapsed + 0.05
                DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                    guard let self = self else { return }
                    if let idx = self.entries.firstIndex(where: { $0.id == id }) {
                        _ = withAnimation(.easeOut(duration: 0.3)) {
                            self.entries.remove(at: idx)
                        }
                    }
                }
            }
        }
    }
}
