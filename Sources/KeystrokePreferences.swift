import Combine
import CoreGraphics
import Foundation

final class KeystrokePreferences: ObservableObject {
    private enum Key {
        static let visibleKeyCount = "visibleKeyCount"
        static let shortcutsOnly = "shortcutsOnly"
        static let keyBackgroundOpacity = "keyBackgroundOpacity"
        static let fadeDelay = "fadeDelay"
        static let keySize = "keySize"
        static let showModifiers = "showModifiers"
        static let overlayOriginX = "overlayOriginX"
        static let overlayOriginY = "overlayOriginY"
    }

    private let defaults: UserDefaults

    @Published var visibleKeyCount: Int = 2 {
        didSet {
            let clampedValue = Self.clamp(visibleKeyCount, range: 1...8)
            guard visibleKeyCount == clampedValue else {
                visibleKeyCount = clampedValue
                return
            }
            defaults.set(visibleKeyCount, forKey: Key.visibleKeyCount)
        }
    }

    @Published var shortcutsOnly = false {
        didSet { defaults.set(shortcutsOnly, forKey: Key.shortcutsOnly) }
    }

    @Published var keyBackgroundOpacity: Double = 0.95 {
        didSet {
            let clampedValue = Self.clamp(keyBackgroundOpacity, range: 0.15...1.0)
            guard keyBackgroundOpacity == clampedValue else {
                keyBackgroundOpacity = clampedValue
                return
            }
            defaults.set(keyBackgroundOpacity, forKey: Key.keyBackgroundOpacity)
        }
    }

    @Published var fadeDelay: Double = 2.0 {
        didSet {
            let clampedValue = Self.clamp(fadeDelay, range: 0.5...6.0)
            guard fadeDelay == clampedValue else {
                fadeDelay = clampedValue
                return
            }
            defaults.set(fadeDelay, forKey: Key.fadeDelay)
        }
    }

    @Published var keySize: Double = 50.0 {
        didSet {
            let clampedValue = Self.clamp(keySize, range: 40.0...72.0)
            guard keySize == clampedValue else {
                keySize = clampedValue
                return
            }
            defaults.set(keySize, forKey: Key.keySize)
        }
    }

    @Published var showModifiers: Bool = true {
        didSet {
            defaults.set(showModifiers, forKey: Key.showModifiers)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.visibleKeyCount) != nil {
            visibleKeyCount = Self.clamp(defaults.integer(forKey: Key.visibleKeyCount), range: 1...8)
        }
        shortcutsOnly = defaults.bool(forKey: Key.shortcutsOnly)
        if defaults.object(forKey: Key.keyBackgroundOpacity) != nil {
            keyBackgroundOpacity = Self.clamp(defaults.double(forKey: Key.keyBackgroundOpacity), range: 0.15...1.0)
        }
        if defaults.object(forKey: Key.fadeDelay) != nil {
            fadeDelay = Self.clamp(defaults.double(forKey: Key.fadeDelay), range: 0.5...6.0)
        }
        if defaults.object(forKey: Key.keySize) != nil {
            keySize = Self.clamp(defaults.double(forKey: Key.keySize), range: 40.0...72.0)
        }
        if defaults.object(forKey: Key.showModifiers) != nil {
            showModifiers = defaults.bool(forKey: Key.showModifiers)
        }
    }

    var savedOverlayOrigin: CGPoint? {
        guard defaults.object(forKey: Key.overlayOriginX) != nil,
              defaults.object(forKey: Key.overlayOriginY) != nil else {
            return nil
        }

        return CGPoint(
            x: defaults.double(forKey: Key.overlayOriginX),
            y: defaults.double(forKey: Key.overlayOriginY)
        )
    }

    func saveOverlayOrigin(_ origin: CGPoint) {
        defaults.set(Double(origin.x), forKey: Key.overlayOriginX)
        defaults.set(Double(origin.y), forKey: Key.overlayOriginY)
    }

    func clearOverlayOrigin() {
        defaults.removeObject(forKey: Key.overlayOriginX)
        defaults.removeObject(forKey: Key.overlayOriginY)
    }

    func restoreDefaults() {
        visibleKeyCount = 2
        shortcutsOnly = false
        keyBackgroundOpacity = 0.95
        fadeDelay = 2.0
        keySize = 50.0
        showModifiers = true
    }

    private static func clamp(_ value: Int, range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clamp(_ value: Double, range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
