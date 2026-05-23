import Foundation
import AppKit
import SwiftUI

/// Manages the menu bar status item and its dropdown menu of recent items.
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var savedFrontmostApp: NSRunningApplication?

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                accessibilityDescription: "Smart Clipboard")
            btn.image?.isTemplate = true
            btn.toolTip = "Smart Clipboard"
        }
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func refresh() {
        // Will rebuild on next open via NSMenuDelegate.menuWillOpen
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        // Header
        let header = NSMenuItem(title: "Smart Clipboard", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Open picker
        let open = NSMenuItem(title: "Open Picker  \(AppState.shared.hotkeyDescription)",
                              action: #selector(openPicker), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        // Starred section
        if let starred = try? ClipRepository.shared.starred(), !starred.isEmpty {
            let label = NSMenuItem(title: "Starred", action: nil, keyEquivalent: "")
            label.isEnabled = false
            menu.addItem(label)
            for item in starred.prefix(15) {
                menu.addItem(menuItem(for: item, starred: true))
            }
            menu.addItem(.separator())
        }

        // Recent section
        let recentLabel = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        recentLabel.isEnabled = false
        menu.addItem(recentLabel)

        let recent = (try? ClipRepository.shared.recent(limit: Preferences.maxMenuItems)) ?? []
        if recent.isEmpty {
            let none = NSMenuItem(title: "Nothing copied yet", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for (idx, item) in recent.enumerated() {
                let mi = menuItem(for: item, starred: false)
                if idx < 9 { mi.keyEquivalent = "\(idx + 1)" }
                menu.addItem(mi)
            }
        }

        menu.addItem(.separator())

        // Misc actions
        let clear = NSMenuItem(title: "Clear Unstarred History",
                               action: #selector(clearUnstarred), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Smart Clipboard",
                              action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func menuItem(for item: ClipItem, starred: Bool) -> NSMenuItem {
        let title = (starred ? "★ " : "") + item.preview
        let mi = NSMenuItem(title: title, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
        mi.target = self
        mi.representedObject = item.id
        if let thumb = item.thumbnailImage {
            mi.image = thumb
        } else {
            mi.image = icon(for: item)
        }
        // Alt-click: copy without pasting
        let alt = NSMenuItem(title: "Copy without pasting",
                             action: #selector(menuItemCopyOnly(_:)), keyEquivalent: "")
        alt.target = self
        alt.representedObject = item.id
        alt.isAlternate = true
        alt.keyEquivalentModifierMask = [.option]
        return mi
    }

    private func icon(for item: ClipItem) -> NSImage? {
        let name: String
        switch item.contentType {
        case .text:  name = "doc.text"
        case .image: name = "photo"
        case .files: name = "folder"
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    // MARK: - Actions

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? Int64,
              let item = try? ClipRepository.shared.fetch(id: id) else { return }
        let target = savedFrontmostApp
        Paster.restoreAndPaste(item, activating: target)
    }

    @objc private func menuItemCopyOnly(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? Int64,
              let item = try? ClipRepository.shared.fetch(id: id) else { return }
        Paster.restore(item)
    }

    @objc private func openPicker() {
        PickerPanel.shared.toggle()
    }

    @objc private func openSettings() {
        SettingsWindow.shared.show()
    }

    @objc private func clearUnstarred() {
        let alert = NSAlert()
        alert.messageText = "Clear all unstarred items?"
        alert.informativeText = "Starred items will be kept."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            try? ClipRepository.shared.deleteAllUnstarred()
            AppState.shared.refresh()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Capture the app that was active before we opened the menu, so we
        // can paste back into it. Status-item menus don't activate our app
        // in the runningApplications sense, but `frontmostApplication` updates
        // immediately when the menu opens; capture once here.
        let ourPID = ProcessInfo.processInfo.processIdentifier
        savedFrontmostApp = NSWorkspace.shared.frontmostApplication
        if savedFrontmostApp?.processIdentifier == ourPID {
            savedFrontmostApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && $0.processIdentifier != ourPID
            })
        }
        rebuildMenu()
    }
}
