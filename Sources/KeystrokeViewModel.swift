import SwiftUI
import Combine

class KeystrokeViewModel: ObservableObject {
    /// 修飾鍵 slots [左, 右]，右對齊填入
    @Published var modifierSlots: [String?] = [nil, nil]
    /// 主鍵 slots [左, 右]，滾動緩衝，新鍵從右推入
    @Published var keySlots: [String?] = [nil, nil]
    @Published var isEditing: Bool = false

    private var fadeWorkItem: DispatchWorkItem?
    private let fadeDelay: TimeInterval = 2.0

    func addKeystroke(keyCode: Int, flags: CGEventFlags, characters: String? = nil) {
        let allKeys = KeyMapper.displayKeys(keyCode: keyCode, flags: flags, characters: characters)

        // 最後一個元素永遠是主鍵
        let mainKey = allKeys.last!
        let modifiers = Array(allKeys.dropLast())

        // 修飾鍵：右對齊，最多取最後 2 個
        let mods = Array(modifiers.suffix(2))
        modifierSlots[0] = mods.count == 2 ? mods[0] : nil
        modifierSlots[1] = mods.count >= 1 ? mods[mods.count - 1] : nil

        // 主鍵：滾動緩衝
        keySlots[0] = keySlots[1]
        keySlots[1] = mainKey

        scheduleFadeout()
    }

    private func scheduleFadeout() {
        fadeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.modifierSlots = [nil, nil]
                self.keySlots = [nil, nil]
            }
        }
        fadeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay, execute: item)
    }
}
