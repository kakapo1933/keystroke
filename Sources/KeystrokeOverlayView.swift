import SwiftUI

struct KeystrokeOverlayView: View {
    @ObservedObject var viewModel: KeystrokeViewModel

    private let slotSize: CGFloat = 56
    private let slotSpacing: CGFloat = 6
    private let areaGap: CGFloat = 14

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

            // 4-slot 固定佈局
            HStack(spacing: 0) {
                // 修飾鍵區（slots 0-1）
                HStack(spacing: slotSpacing) {
                    FixedSlot(content: viewModel.modifierSlots[0], size: slotSize)
                    FixedSlot(content: viewModel.modifierSlots[1], size: slotSize)
                }

                Spacer().frame(width: areaGap)

                // 主鍵區（slots 2-3）
                HStack(spacing: slotSpacing) {
                    FixedSlot(content: viewModel.keySlots[0], size: slotSize)
                    FixedSlot(content: viewModel.keySlots[1], size: slotSize)
                }
            }
        }
        .frame(width: panelWidth, height: 90)
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

    /// 計算面板寬度：4 slots + 內部間距 + 區域間距
    private var panelWidth: CGFloat {
        4 * slotSize + 2 * slotSpacing + areaGap + 40 // +40 for outer padding
    }
}

/// 固定位置的 slot 容器：有內容時顯示 KeyCapView，無內容時保留空間
struct FixedSlot: View {
    let content: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let key = content {
                KeyCapView(text: key)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
    }
}

struct KeyCapView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .medium, design: .rounded))
            .foregroundColor(Color(white: 0.15))
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.95))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            )
    }
}
