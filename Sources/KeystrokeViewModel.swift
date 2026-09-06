import SwiftUI
import Combine

final class KeystrokeViewModel: ObservableObject {
    let preferences: KeystrokePreferences
    @Published private(set) var recentEntries: [KeystrokeEntry] = []
    @Published var isEditing = false
    private(set) var isPaused = false
    private var fadeWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(preferences: KeystrokePreferences) {
        self.preferences = preferences
        preferences.$shortcutsOnly.dropFirst().removeDuplicates()
            .sink { [weak self] _ in self?.clear() }
            .store(in: &cancellables)
    }

    var entrySlots: [KeystrokeEntry?] {
        let entries = Array(recentEntries.suffix(preferences.visibleKeyCount))
        return Array(repeating: nil, count: preferences.visibleKeyCount - entries.count)
            + entries.map(Optional.some)
    }

    func addKeystroke(keyCode: Int, flags: CGEventFlags, characters: String? = nil) {
        let shortcut = KeyMapper.isShortcut(keyCode: keyCode, flags: flags)
        guard !isPaused, !preferences.shortcutsOnly || shortcut else { return }
        let keys = KeyMapper.displayKeys(keyCode: keyCode, flags: flags, characters: characters)
        guard let key = keys.last else { return }
        append(KeystrokeEntry(key: key, modifiers: Array(keys.dropLast()), isShortcut: shortcut))
    }

    func addDisplayKey(_ key: String, isShortcut: Bool = true) {
        guard !isPaused, !preferences.shortcutsOnly || isShortcut else { return }
        append(KeystrokeEntry(key: key, isShortcut: isShortcut))
    }

    func showPreview() {
        guard !isPaused else { return }
        recentEntries = KeystrokeEntry.preview(count: preferences.visibleKeyCount)
        scheduleFadeout()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        clear()
    }

    func clear() {
        fadeWorkItem?.cancel()
        fadeWorkItem = nil
        recentEntries = []
    }

    private func append(_ entry: KeystrokeEntry) {
        recentEntries = Array((recentEntries + [entry]).suffix(preferences.visibleKeyCount))
        scheduleFadeout()
    }

    private func scheduleFadeout() {
        fadeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) { self?.recentEntries = [] }
        }
        fadeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + preferences.fadeDelay, execute: item)
    }
}
