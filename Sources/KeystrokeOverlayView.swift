import SwiftUI

struct KeystrokeOverlayView: View {
    @ObservedObject var viewModel: KeystrokeViewModel
    @ObservedObject var preferences: KeystrokePreferences

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

            KeystrokeStrip(entries: viewModel.entrySlots, preferences: preferences)
            .padding(.horizontal, horizontalPadding)
        }
        .frame(width: panelWidth, height: panelHeight)
        .contentShape(Rectangle())
        .background(viewModel.isEditing ? Color.black.opacity(0.001) : Color.clear)
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
        let width = groupWidth(count: preferences.visibleKeyCount, slotSize: slotSize) + 40
        let height = max(90, keySize + 40)

        return CGSize(width: width, height: height)
    }

    private static func groupWidth(count: Int, slotSize: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * slotSize + CGFloat(count - 1) * 6
    }

    private var panelWidth: CGFloat {
        Self.panelSize(for: preferences).width
    }

    private var panelHeight: CGFloat {
        Self.panelSize(for: preferences).height
    }
}

/// Shared by the overlay and settings so slot count and spacing match exactly.
struct KeystrokeStrip: View {
    let entries: [KeystrokeEntry?]
    @ObservedObject var preferences: KeystrokePreferences

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                ZStack {
                    if let entry {
                        KeyCapView(text: entry.key, modifiers: entry.modifiers, preferences: preferences)
                            .transition(.opacity)
                    }
                }
                .frame(width: CGFloat(preferences.keySize) + 6, height: CGFloat(preferences.keySize) + 6)
            }
        }
    }
}

struct KeyCapView: View {
    let text: String
    var modifiers: [String] = []
    @ObservedObject var preferences: KeystrokePreferences

    var body: some View {
        VStack(spacing: 0) {
            if preferences.showModifiers, !modifiers.isEmpty {
                Text(modifiers.joined())
                    .font(.system(size: keySize * 0.22, weight: .semibold))
                    .foregroundColor(Color(white: 0.22))
                    .lineLimit(1)
                KeyCapContent(text: text, fontSize: fontSize * 0.85)
                    .frame(height: keySize * 0.48)
            } else {
                KeyCapContent(text: text, fontSize: fontSize)
            }
        }
            .frame(width: keySize, height: keySize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel((preferences.showModifiers ? modifiers.joined() : "") + text)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(preferences.keyBackgroundOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(shadowOpacity), radius: 5, y: 2)
            )
    }

    private var keySize: CGFloat {
        CGFloat(preferences.keySize)
    }

    private var fontSize: CGFloat {
        max(16, keySize * 0.44)
    }

    private var borderOpacity: Double {
        0.18 + preferences.keyBackgroundOpacity * 0.24
    }

    private var shadowOpacity: Double {
        0.10 + preferences.keyBackgroundOpacity * 0.14
    }
}

private struct KeyCapContent: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        Group {
            if let kind = MediaKeyGlyph.Kind(token: text) {
                MediaKeyGlyph(kind: kind)
                    .padding(fontSize * 0.24)
            } else {
                Text(text)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.52)
                    .lineLimit(1)
            }
        }
        .foregroundColor(Color(white: 0.12))
        .shadow(color: .white.opacity(0.25), radius: 0, y: 1)
    }
}

private struct MediaKeyGlyph: View {
    enum Kind {
        case volumeUp
        case volumeDown
        case mute
        case playPause
        case nextTrack
        case previousTrack
        case fastForward
        case rewind

        init?(token: String) {
            switch token {
            case KeyDisplayToken.volumeUp:
                self = .volumeUp
            case KeyDisplayToken.volumeDown:
                self = .volumeDown
            case KeyDisplayToken.mute:
                self = .mute
            case KeyDisplayToken.playPause:
                self = .playPause
            case KeyDisplayToken.nextTrack:
                self = .nextTrack
            case KeyDisplayToken.previousTrack:
                self = .previousTrack
            case KeyDisplayToken.fastForward:
                self = .fastForward
            case KeyDisplayToken.rewind:
                self = .rewind
            default:
                return nil
            }
        }
    }

    let kind: Kind

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08, dy: size.height * 0.18)
            let color = Color(white: 0.12)

            switch kind {
            case .volumeUp:
                drawSpeaker(in: rect, context: &context, color: color, waveCount: 3)
            case .volumeDown:
                drawSpeaker(in: rect, context: &context, color: color, waveCount: 1)
            case .mute:
                drawSpeaker(in: rect, context: &context, color: color, waveCount: 0)
                drawMuteMark(in: rect, context: &context, color: color)
            case .playPause:
                drawPlayPause(in: rect, context: &context, color: color)
            case .nextTrack:
                drawTransport(in: rect, context: &context, color: color, direction: .next, hasStopBar: true)
            case .previousTrack:
                drawTransport(in: rect, context: &context, color: color, direction: .previous, hasStopBar: true)
            case .fastForward:
                drawTransport(in: rect, context: &context, color: color, direction: .next, hasStopBar: false)
            case .rewind:
                drawTransport(in: rect, context: &context, color: color, direction: .previous, hasStopBar: false)
            }
        }
        .accessibilityHidden(true)
    }

    private enum TransportDirection {
        case next
        case previous
    }

    private func drawSpeaker(
        in rect: CGRect,
        context: inout GraphicsContext,
        color: Color,
        waveCount: Int
    ) {
        let box = CGRect(
            x: rect.minX,
            y: rect.midY - rect.height * 0.17,
            width: rect.width * 0.18,
            height: rect.height * 0.34
        )
        let hornRight = rect.minX + rect.width * 0.42
        let hornInset = rect.height * 0.08

        var speaker = Path()
        speaker.addRoundedRect(in: box, cornerSize: CGSize(width: box.width * 0.22, height: box.width * 0.22))
        speaker.move(to: CGPoint(x: box.maxX, y: box.minY + hornInset))
        speaker.addLine(to: CGPoint(x: hornRight, y: rect.minY))
        speaker.addLine(to: CGPoint(x: hornRight, y: rect.maxY))
        speaker.addLine(to: CGPoint(x: box.maxX, y: box.maxY - hornInset))
        speaker.closeSubpath()
        context.fill(speaker, with: .color(color))

        guard waveCount > 0 else { return }

        let center = CGPoint(x: hornRight - rect.width * 0.03, y: rect.midY)
        let lineWidth = max(2, rect.width * 0.055)
        for index in 0..<waveCount {
            let radius = rect.width * (0.18 + CGFloat(index) * 0.115)
            var wave = Path()
            wave.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-36),
                endAngle: .degrees(36),
                clockwise: false
            )
            context.stroke(wave, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }

    private func drawMuteMark(in rect: CGRect, context: inout GraphicsContext, color: Color) {
        var mark = Path()
        let left = rect.minX + rect.width * 0.66
        let right = rect.minX + rect.width * 0.92
        let top = rect.minY + rect.height * 0.23
        let bottom = rect.maxY - rect.height * 0.23
        mark.move(to: CGPoint(x: left, y: top))
        mark.addLine(to: CGPoint(x: right, y: bottom))
        mark.move(to: CGPoint(x: right, y: top))
        mark.addLine(to: CGPoint(x: left, y: bottom))
        context.stroke(mark, with: .color(color), style: StrokeStyle(lineWidth: max(2, rect.width * 0.065), lineCap: .round))
    }

    private func drawPlayPause(in rect: CGRect, context: inout GraphicsContext, color: Color) {
        var play = Path()
        play.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.14))
        play.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.14))
        play.addLine(to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.midY))
        play.closeSubpath()
        context.fill(play, with: .color(color))

        let barWidth = rect.width * 0.12
        let barHeight = rect.height * 0.72
        let barY = rect.midY - barHeight / 2
        let firstBar = CGRect(x: rect.minX + rect.width * 0.66, y: barY, width: barWidth, height: barHeight)
        let secondBar = CGRect(x: rect.minX + rect.width * 0.84, y: barY, width: barWidth, height: barHeight)
        context.fill(Path(roundedRect: firstBar, cornerRadius: barWidth * 0.18), with: .color(color))
        context.fill(Path(roundedRect: secondBar, cornerRadius: barWidth * 0.18), with: .color(color))
    }

    private func drawTransport(
        in rect: CGRect,
        context: inout GraphicsContext,
        color: Color,
        direction: TransportDirection,
        hasStopBar: Bool
    ) {
        if hasStopBar {
            let barWidth = rect.width * 0.08
            let barHeight = rect.height * 0.72
            let x = direction == .next ? rect.maxX - barWidth : rect.minX
            let bar = CGRect(x: x, y: rect.midY - barHeight / 2, width: barWidth, height: barHeight)
            context.fill(Path(roundedRect: bar, cornerRadius: barWidth * 0.2), with: .color(color))
        }

        let contentMinX = rect.minX + (direction == .previous && hasStopBar ? rect.width * 0.13 : 0)
        let contentMaxX = rect.maxX - (direction == .next && hasStopBar ? rect.width * 0.13 : 0)
        let available = contentMaxX - contentMinX
        let gap = available * 0.04
        let triangleWidth = (available - gap) / 2

        for index in 0..<2 {
            let x = contentMinX + CGFloat(index) * (triangleWidth + gap)
            let triangleRect = CGRect(
                x: x,
                y: rect.midY - rect.height * 0.34,
                width: triangleWidth,
                height: rect.height * 0.68
            )
            context.fill(transportTriangle(in: triangleRect, direction: direction), with: .color(color))
        }
    }

    private func transportTriangle(in rect: CGRect, direction: TransportDirection) -> Path {
        var path = Path()
        switch direction {
        case .next:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        case .previous:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        }
        path.closeSubpath()
        return path
    }
}
