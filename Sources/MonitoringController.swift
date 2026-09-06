import Cocoa
import Combine

protocol KeystrokeMonitoring: AnyObject {
    var isRunning: Bool { get }
    func start() -> Bool
    func stop()
}

final class MonitoringController: ObservableObject {
    enum State: String {
        case waitingForPermission, running, paused, failed

        var title: String {
            switch self {
            case .waitingForPermission: return "等待輔助使用權限"
            case .running: return "監聽中"
            case .paused: return "已暫停"
            case .failed: return "監聽啟動失敗"
            }
        }

        var detail: String {
            switch self {
            case .waitingForPermission: return "請在系統設定允許 KeyStroke 使用輔助使用權限，授權後會自動重試。"
            case .running: return "按鍵會顯示在浮層。暫停會停止監聽並清空畫面。"
            case .paused: return "已停止鍵盤監聽並清空畫面；繼續後只顯示新的按鍵。"
            case .failed: return "請檢查輔助使用與輸入監控權限，再按重試。"
            }
        }
    }

    @Published private(set) var state: State = .waitingForPermission
    private let monitor: KeystrokeMonitoring
    private let viewModel: KeystrokeViewModel
    private let hasPermission: () -> Bool
    private var healthTimer: Timer?

    init(monitor: KeystrokeMonitoring, viewModel: KeystrokeViewModel,
         hasPermission: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.monitor = monitor
        self.viewModel = viewModel
        self.hasPermission = hasPermission
    }

    func start() {
        retry()
        guard healthTimer == nil else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.checkHealth() }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        healthTimer = timer
    }

    func retry() {
        guard state != .paused else { return }
        guard hasPermission() else {
            monitor.stop()
            viewModel.clear()
            transition(to: .waitingForPermission)
            return
        }
        transition(to: monitor.start() ? .running : .failed)
    }

    func togglePause() {
        if state == .paused {
            viewModel.setPaused(false)
            transition(to: .waitingForPermission)
            retry()
        } else {
            monitor.stop()
            viewModel.setPaused(true)
            transition(to: .paused)
        }
    }

    /// Also callable in tests without waiting for a wall-clock timer.
    func checkHealth() {
        guard state != .paused else { return }
        if !hasPermission() {
            if state != .waitingForPermission {
                monitor.stop()
                viewModel.clear()
                transition(to: .waitingForPermission)
            }
        } else if state == .waitingForPermission {
            retry()
        } else if state == .running, !monitor.isRunning {
            monitor.stop()
            viewModel.clear()
            transition(to: .failed)
        }
    }

    func shutdown() {
        healthTimer?.invalidate()
        healthTimer = nil
        monitor.stop()
        viewModel.setPaused(true)
    }

    private func transition(to next: State) {
        guard state != next else { return }
        state = next
        AppLog.lifecycle.notice("Monitoring state: \(next.rawValue, privacy: .public)")
    }

    deinit { healthTimer?.invalidate() }
}
