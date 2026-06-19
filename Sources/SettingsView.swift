import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: KeystrokePreferences

    let preview: () -> Void
    let resetPosition: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                settingsSection("Display") {
                    stepperRow("Visible keys", value: $preferences.visibleKeyCount, range: 1...8)
                    Toggle("Show modifiers", isOn: $preferences.showModifiers)
                    stepperRow("Modifier slots", value: $preferences.visibleModifierCount, range: 0...4)
                        .disabled(!preferences.showModifiers)
                }

                settingsSection("Appearance") {
                    sliderRow(
                        title: "Background",
                        value: $preferences.keyBackgroundOpacity,
                        range: 0.15...1.0,
                        step: 0.05,
                        displayValue: "\(Int(preferences.keyBackgroundOpacity * 100))%"
                    )

                    sliderRow(
                        title: "Key size",
                        value: $preferences.keySize,
                        range: 40...72,
                        step: 1,
                        displayValue: "\(Int(preferences.keySize)) px"
                    )
                }

                settingsSection("Timing") {
                    sliderRow(
                        title: "Hold on screen",
                        value: $preferences.fadeDelay,
                        range: 0.5...6.0,
                        step: 0.5,
                        displayValue: String(format: "%.1f s", preferences.fadeDelay)
                    )
                }
            }

            SettingsPreviewStrip(preferences: preferences)

            Divider()

            HStack {
                Button(action: preview) {
                    Label("Preview Keys", systemImage: "sparkles")
                }

                Button(action: resetPosition) {
                    Label("Reset Position", systemImage: "arrow.down.to.line")
                }

                Spacer()

                Button("Restore Defaults") {
                    preferences.restoreDefaults()
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 560)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("KeyStroke")
                    .font(.title3.weight(.semibold))
                Text("Overlay Settings")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private func stepperRow(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper("\(value.wrappedValue)", value: value, in: range)
                .monospacedDigit()
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayValue: String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step)
                    .frame(width: 210)
                Text(displayValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}

private struct SettingsPreviewStrip: View {
    @ObservedObject var preferences: KeystrokePreferences

    private let modifiers = ["⌃", "⌥", "⇧", "⌘"]
    private let keys = [
        KeyDisplayToken.volumeDown,
        KeyDisplayToken.volumeUp,
        KeyDisplayToken.playPause,
        KeyDisplayToken.previousTrack,
        KeyDisplayToken.nextTrack
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if preferences.showModifiers {
                    ForEach(Array(modifiers.suffix(preferences.visibleModifierCount)), id: \.self) { key in
                        KeyCapView(text: key, preferences: preferences)
                    }

                    if preferences.visibleModifierCount > 0 {
                        Spacer()
                            .frame(width: 6)
                    }
                }

                ForEach(Array(keys.suffix(preferences.visibleKeyCount)), id: \.self) { key in
                    KeyCapView(text: key, preferences: preferences)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .frame(height: CGFloat(preferences.keySize) + 18)
    }
}
