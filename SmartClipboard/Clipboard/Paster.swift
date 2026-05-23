import Foundation
import AppKit
import Carbon.HIToolbox

enum Paster {
    /// Place the item back onto the system pasteboard.
    /// `ignoreCapture` tells the monitor not to re-ingest this change.
    static func restore(_ item: ClipItem, ignoreCapture: Bool = true) {
        let pb = NSPasteboard.general
        if ignoreCapture {
            ClipboardMonitor.shared.markOwnWrite(fingerprint: ClipboardMonitor.fingerprint(item))
        }
        pb.clearContents()

        switch item.contentType {
        case .text:
            if let s = item.textContent {
                pb.setString(s, forType: .string)
            }
        case .image:
            if let d = item.imageData, let img = NSImage(data: d) {
                pb.writeObjects([img])
            }
        case .files:
            let urls = item.fileURLList as [NSURL]
            if !urls.isEmpty {
                pb.writeObjects(urls)
            }
        }

        // Bump access timestamp asynchronously
        if let id = item.id {
            DispatchQueue.global(qos: .utility).async {
                try? ClipRepository.shared.touch(id: id)
            }
        }
    }

    /// Restore the item and synthesize Cmd+V into the focused app.
    /// If `activating` is provided, the target app is brought to front
    /// first and we wait for activation before synthesizing the keystroke.
    static func restoreAndPaste(_ item: ClipItem, activating target: NSRunningApplication? = nil) {
        restore(item)
        if let target {
            target.activate(options: [.activateIgnoringOtherApps])
            waitForActivation(target, retriesLeft: 10) {
                sendCommandV()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                sendCommandV()
            }
        }
    }

    private static func waitForActivation(_ app: NSRunningApplication,
                                          retriesLeft: Int,
                                          completion: @escaping () -> Void) {
        if app.isActive || retriesLeft <= 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: completion)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            waitForActivation(app, retriesLeft: retriesLeft - 1, completion: completion)
        }
    }

    private static func sendCommandV() {
        guard PermissionsHelper.accessibilityGranted() else {
            NSLog("SmartClipboard: Accessibility not granted; skipping ⌘V synth.")
            return
        }
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
