import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: KeystrokePreferences

    let preview: () -> Void
    let resetPosition: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            Form {
                Section("Display") {
                    LabeledContent("Visible keys") {
                        Stepper("\(preferences.visibleKeyCount)", value: $preferences.visibleKeyCount, in: 1...8)
                            .monospacedDigit()
                    }

                    Toggle("Show modifiers", isOn: $preferences.showModifiers)

                    LabeledContent("Modifier slots") {
                        Stepper("\(preferences.visibleModifierCount)", value: $preferences.visibleModifierCount, in: 0...4)
                            .monospacedDigit()
                            .disabled(!preferences.showModifiers)
                    }
                }

                Section("Appearance") {
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

                Section("Timing") {
                    sliderRow(
                        title: "Hold on screen",
                        value: $preferences.fadeDelay,
                        range: 0.5...6.0,
                        step: 0.5,
                        displayValue: String(format: "%.1f s", preferences.fadeDelay)
                    )
                }
            }
            .formStyle(.grouped)

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
        .frame(width: 520, height: 500)
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
    private let keys = ["K", "E", "Y", "⏎", "⌫", "↑", "F5", "⌘"]

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
    }
}
