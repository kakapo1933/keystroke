import SwiftUI

struct KeystrokeOverlayView: View {
    @ObservedObject var viewModel: KeystrokeViewModel
    @ObservedObject var preferences: KeystrokePreferences

    private let slotSpacing: CGFloat = 6
    private let areaGap: CGFloat = 12
    private let horizontalPadding: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottom) {
            // 編輯模式指示
            if viewModel.isEditing {
                VStack {
                    Text("拖曳以調整位置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
            }

            HStack(spacing: 0) {
                if preferences.showModifiers, !viewModel.modifierSlots.isEmpty {
                    HStack(spacing: slotSpacing) {
                        ForEach(Array(viewModel.modifierSlots.enumerated()), id: \.offset) { _, content in
                            FixedSlot(content: content, size: slotSize, preferences: preferences)
                        }
                    }

                    if !viewModel.keySlots.isEmpty {
                        Spacer().frame(width: areaGap)
                    }
                }

                HStack(spacing: slotSpacing) {
                    ForEach(Array(viewModel.keySlots.enumerated()), id: \.offset) { _, content in
                        FixedSlot(content: content, size: slotSize, preferences: preferences)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        .frame(width: panelWidth, height: panelHeight)
        .overlay(
            Group {
                if viewModel.isEditing {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        )
    }

    static func panelSize(for preferences: KeystrokePreferences) -> CGSize {
        let keySize = CGFloat(preferences.keySize)
        let slotSize = keySize + 6
        let visibleModifierCount = preferences.showModifiers ? preferences.visibleModifierCount : 0
        let keyCount = preferences.visibleKeyCount
        let modifierWidth = groupWidth(count: visibleModifierCount, slotSize: slotSize)
        let keyWidth = groupWidth(count: keyCount, slotSize: slotSize)
        let gap = visibleModifierCount > 0 && keyCount > 0 ? CGFloat(12) : 0
        let width = modifierWidth + keyWidth + gap + 40
        let height = max(90, keySize + 40)

        return CGSize(width: width, height: height)
    }

    private static func groupWidth(count: Int, slotSize: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * slotSize + CGFloat(count - 1) * 6
    }

    private var slotSize: CGFloat {
        CGFloat(preferences.keySize) + 6
    }

    private var panelWidth: CGFloat {
        Self.panelSize(for: preferences).width
    }

    private var panelHeight: CGFloat {
        Self.panelSize(for: preferences).height
    }
}

/// 固定位置的 slot 容器：有內容時顯示 KeyCapView，無內容時保留空間
struct FixedSlot: View {
    let content: String?
    let size: CGFloat
    @ObservedObject var preferences: KeystrokePreferences

    var body: some View {
        ZStack {
            if let key = content {
                KeyCapView(text: key, preferences: preferences)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
    }
}

struct KeyCapView: View {
    let text: String
    @ObservedObject var preferences: KeystrokePreferences

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.52)
            .lineLimit(1)
            .foregroundColor(Color(white: 0.12))
            .shadow(color: .white.opacity(0.25), radius: 0, y: 1)
            .frame(width: keySize, height: keySize)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(preferences.keyBackgroundOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
            )
    }

    private var keySize: CGFloat {
        CGFloat(preferences.keySize)
    }

    private var fontSize: CGFloat {
        max(16, keySize * 0.44)
    }
}
