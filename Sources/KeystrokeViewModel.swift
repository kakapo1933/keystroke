import SwiftUI
import Combine

class KeystrokeViewModel: ObservableObject {
    let preferences: KeystrokePreferences

    @Published private var modifierKeys: [String] = []
    @Published private var recentKeys: [String] = []
    @Published var isEditing: Bool = false

    private var fadeWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(preferences: KeystrokePreferences) {
        self.preferences = preferences

        preferences.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    var modifierSlots: [String?] {
        guard preferences.showModifiers, preferences.visibleModifierCount > 0 else {
            return []
        }

        let visibleModifiers = Array(modifierKeys.suffix(preferences.visibleModifierCount))
        let emptyCount = max(preferences.visibleModifierCount - visibleModifiers.count, 0)
        return Array(repeating: nil, count: emptyCount) + visibleModifiers.map(Optional.some)
    }

    var keySlots: [String?] {
        let visibleKeys = Array(recentKeys.suffix(preferences.visibleKeyCount))
        let emptyCount = max(preferences.visibleKeyCount - visibleKeys.count, 0)
        return Array(repeating: nil, count: emptyCount) + visibleKeys.map(Optional.some)
    }

    func addKeystroke(keyCode: Int, flags: CGEventFlags, characters: String? = nil) {
        let allKeys = KeyMapper.displayKeys(keyCode: keyCode, flags: flags, characters: characters)

        // 最後一個元素永遠是主鍵
        let mainKey = allKeys.last!
        let modifiers = Array(allKeys.dropLast())

        modifierKeys = Array(modifiers.suffix(preferences.visibleModifierCount))
        recentKeys.append(mainKey)
        recentKeys = Array(recentKeys.suffix(preferences.visibleKeyCount))

        scheduleFadeout()
    }

    func addDisplayKey(_ key: String) {
        modifierKeys = []
        recentKeys.append(key)
        recentKeys = Array(recentKeys.suffix(preferences.visibleKeyCount))
        scheduleFadeout()
    }

    func showPreview() {
        modifierKeys = Array(["⌃", "⌥", "⇧", "⌘"].suffix(preferences.visibleModifierCount))
        recentKeys = Array(["K", "E", "Y", "⏎", "⌫", "↑", "F5", "⌘"].suffix(preferences.visibleKeyCount))
        scheduleFadeout()
    }

    private func scheduleFadeout() {
        fadeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.modifierKeys = []
                self.recentKeys = []
            }
        }
        fadeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + preferences.fadeDelay, execute: item)
    }
}
