import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: KeystrokePreferences
    @ObservedObject var monitoring: MonitoringController

    let openPermissions: () -> Void
    let preview: () -> Void
    let resetPosition: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    settingsSection("監聽狀態") {
                        HStack {
                            Label(monitoring.state.title, systemImage: monitoring.state == .running ? "checkmark.circle.fill" : "pause.circle")
                            Spacer()
                            Button(monitoring.state == .paused ? "繼續監聽" : "暫停監聽") { monitoring.togglePause() }
                            if monitoring.state == .failed || monitoring.state == .waitingForPermission {
                                Button("重試") { monitoring.retry() }
                                Button("開啟權限設定", action: openPermissions)
                            }
                        }
                        Text(monitoring.state.detail).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    settingsSection("顯示") {
                        stepperRow("顯示筆數", value: $preferences.visibleKeyCount, range: 1...8)
                        Toggle("顯示修飾鍵", isOn: $preferences.showModifiers)
                        Toggle("只顯示快捷鍵", isOn: $preferences.shortcutsOnly)
                        Text("顯示 ⌘／⌃／⌥ 組合鍵、F1–F20 與媒體鍵；隱藏一般文字與 Shift 單獨輸入。")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    settingsSection("外觀") {
                        sliderRow(
                            title: "背景不透明度",
                            value: $preferences.keyBackgroundOpacity,
                            range: 0.15...1.0,
                            step: 0.05,
                            displayValue: "\(Int(preferences.keyBackgroundOpacity * 100))%"
                        )

                        sliderRow(
                            title: "按鍵大小",
                            value: $preferences.keySize,
                            range: 40...72,
                            step: 1,
                            displayValue: "\(Int(preferences.keySize)) px"
                        )
                    }

                    settingsSection("時間") {
                        sliderRow(
                            title: "停留時間",
                            value: $preferences.fadeDelay,
                            range: 0.5...6.0,
                            step: 0.5,
                            displayValue: String(format: "%.1f s", preferences.fadeDelay)
                        )
                    }
                    settingsSection("顯示預覽 · \(preferences.visibleKeyCount) 筆") {
                        SettingsPreviewStrip(preferences: preferences)
                    }
                }
                .padding(.horizontal, 2)
            }

            Divider()

            HStack {
                Button(action: preview) {
                    Label("預覽按鍵", systemImage: "sparkles")
                }
                .disabled(monitoring.state == .paused)

                Button(action: resetPosition) {
                    Label("重設位置", systemImage: "arrow.down.to.line")
                }

                Spacer()

                Button("還原預設值") {
                    preferences.restoreDefaults()
                }
            }
        }
        .padding(20)
        .frame(width: 580, height: 700)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("KeyStroke")
                    .font(.title3.weight(.semibold))
                Text("按鍵顯示設定")
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step)
                    .accessibilityLabel(title)
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            KeystrokeStrip(
                entries: KeystrokeEntry.preview(count: preferences.visibleKeyCount).map(Optional.some),
                preferences: preferences
            )
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .frame(height: CGFloat(preferences.keySize) + 30)
    }
}
