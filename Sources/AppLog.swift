import OSLog

enum AppLog {
    // Log lifecycle/state only. Never record key contents or typed text.
    static let lifecycle = Logger(subsystem: "com.keystroke.app", category: "lifecycle")
}
