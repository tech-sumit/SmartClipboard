import SwiftUI
import AppKit

@main
struct SmartClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // LSUIElement app — we manage windows manually via AppDelegate/MenuBarController.
        // This empty Settings scene satisfies SwiftUI's scene requirement; we use our
        // own SettingsWindow class instead because Settings scenes don't behave well
        // for menu-bar-only apps.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Touch the database so migrations run early
        _ = AppDatabase.shared

        // Install menu bar
        MenuBarController.shared.install()

        // Start clipboard monitor
        ClipboardMonitor.shared.onNewItem = { _ in
            AppState.shared.refresh()
            BackupManager.shared.clipChanged()
        }
        ClipboardMonitor.shared.start()

        // Register global hotkey
        HotkeyManager.shared.onTrigger = {
            PickerPanel.shared.toggle()
        }
        HotkeyManager.shared.register(
            keyCode: Preferences.hotkeyKeyCode,
            modifiers: Preferences.hotkeyModifiers
        )

        // First-launch nudge for Accessibility
        if !PermissionsHelper.accessibilityGranted() {
            // Don't prompt immediately; just log. Settings shows a clear prompt button.
            NSLog("SmartClipboard: Accessibility not granted; paste-on-Enter disabled until enabled in System Settings.")
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { URLSchemeHandler.handle(url) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        HotkeyManager.shared.unregister()
    }
}
