import Foundation
import AppKit
import SwiftUI

/// Floating, non-activating panel that hosts the SwiftUI picker.
/// Non-activating so the previously-focused app keeps its keyboard focus
/// (until we send ⌘V into it).
final class PickerPanel: NSObject, NSWindowDelegate {
    static let shared = PickerPanel()

    private var panel: NonActivatingPanel?
    private var savedFrontmostApp: NSRunningApplication?
    private var ignoreNextResign = false

    func toggle() {
        if let p = panel, p.isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        // Capture frontmost app BEFORE we show the panel.
        savedFrontmostApp = NSWorkspace.shared.frontmostApplication

        AppState.shared.searchQuery = ""
        AppState.shared.refresh()

        if panel == nil { build() }
        guard let panel else { return }

        // Center near top of main screen
        if let screen = NSScreen.main {
            let size = panel.frame.size
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.maxY - size.height - 200
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// Called when the user picks an item.
    func commit(_ item: ClipItem, pasteAfter: Bool) {
        close()
        if pasteAfter {
            Paster.restoreAndPaste(item, activating: savedFrontmostApp)
        } else {
            Paster.restore(item)
        }
    }

    private func build() {
        let view = PickerView(
            onSelect: { [weak self] item in self?.commit(item, pasteAfter: true) },
            onCopyOnly: { [weak self] item in self?.commit(item, pasteAfter: false) },
            onClose: { [weak self] in self?.close() }
        )
        .environmentObject(AppState.shared)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 560, height: 440)

        let p = NonActivatingPanel(
            contentRect: host.frame,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered, defer: false
        )
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .windowBackgroundColor
        p.contentView = host
        p.delegate = self
        panel = p
    }

    // MARK: NSWindowDelegate

    /// Close the panel as soon as it loses key-window status —
    /// i.e. the user clicked outside of it.
    func windowDidResignKey(_ notification: Notification) {
        guard !ignoreNextResign else {
            ignoreNextResign = false
            return
        }
        close()
    }
}

/// NSPanel that can become key without activating the app.
final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
