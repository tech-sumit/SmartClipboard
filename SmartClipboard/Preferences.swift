import Foundation
import AppKit

enum Preferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let hotkeyKeyCode = "hotkey.keyCode"
        static let hotkeyModifiers = "hotkey.modifiers"
        static let backupFolderBookmark = "backup.folderBookmark"
        static let autoBackupEnabled = "backup.autoEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let maxMenuItems = "menu.maxItems"
    }

    // Default: Cmd+Shift+V → keyCode 9 (V), modifiers = cmd+shift
    static var hotkeyKeyCode: UInt32 {
        get {
            let v = defaults.integer(forKey: Key.hotkeyKeyCode)
            return v == 0 ? 9 : UInt32(v)
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyKeyCode) }
    }

    // Carbon modifier mask: cmdKey | shiftKey = 0x0100 | 0x0200 = 0x0300
    static var hotkeyModifiers: UInt32 {
        get {
            let v = defaults.integer(forKey: Key.hotkeyModifiers)
            return v == 0 ? 0x0300 : UInt32(v)
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyModifiers) }
    }

    static var backupFolderBookmark: Data? {
        get { defaults.data(forKey: Key.backupFolderBookmark) }
        set { defaults.set(newValue, forKey: Key.backupFolderBookmark) }
    }

    static var autoBackupEnabled: Bool {
        get { defaults.bool(forKey: Key.autoBackupEnabled) }
        set { defaults.set(newValue, forKey: Key.autoBackupEnabled) }
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    static var maxMenuItems: Int {
        get {
            let v = defaults.integer(forKey: Key.maxMenuItems)
            return v == 0 ? 25 : v
        }
        set { defaults.set(newValue, forKey: Key.maxMenuItems) }
    }
}
