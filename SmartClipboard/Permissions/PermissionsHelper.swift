import Foundation
import AppKit
import ApplicationServices

enum PermissionsHelper {
    /// Returns true if the app already has Accessibility (AX) permission.
    static func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the OS to show the Accessibility access dialog.
    /// Returns true if currently granted; even if false, this triggers the prompt
    /// the first time and adds the app to the System Settings list.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let opts: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Open the Accessibility pane of System Settings.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open the Input Monitoring pane of System Settings.
    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
