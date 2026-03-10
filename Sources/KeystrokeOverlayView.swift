import SwiftUI

struct KeystrokeOverlayView: View {
    @ObservedObject var viewModel: KeystrokeViewModel

    var body: some View {
        ZStack {
            // Editing indicator
            if viewModel.isEditing {
                VStack {
                    Text("拖曳以調整位置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 16)
                    Spacer()
                }
            }

            // Keystroke pills — no implicit animation, insertions are instant
            VStack(spacing: 6) {
                Spacer()
                ForEach(viewModel.entries) { entry in
                    KeystrokePill(text: entry.text)
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(width: 400, height: 260, alignment: .bottom)
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
}

struct KeystrokePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 26, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.08, opacity: 0.85))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            )
    }
}
