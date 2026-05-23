import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Wraps a single SwiftUI Settings window. Settings scene isn't great for
/// LSUIElement apps, so we manage our own window.
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            let win = NSWindow(contentViewController: host)
            win.title = "Smart Clipboard Settings"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.setContentSize(NSSize(width: 520, height: 480))
            win.isReleasedWhenClosed = false
            win.delegate = self
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep window around to preserve state
    }
}

struct SettingsView: View {
    @State private var hotkeyDescription: String = AppState.shared.hotkeyDescription
    @State private var capturingHotkey = false
    @State private var autoBackup: Bool = Preferences.autoBackupEnabled
    @State private var backupFolderPath: String = BackupManager.shared.resolvedFolderPath() ?? "Not set"
    @State private var maxMenuItems: Double = Double(Preferences.maxMenuItems)
    @State private var accessibilityGranted: Bool = PermissionsHelper.accessibilityGranted()
    @State private var dbCount: Int = (try? ClipRepository.shared.count()) ?? 0
    @State private var statusMessage: String = ""

    var body: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Open Picker")
                    Spacer()
                    Button(capturingHotkey ? "Press keys…" : hotkeyDescription) {
                        capturingHotkey.toggle()
                    }
                    .frame(minWidth: 120)
                    .background(HotkeyCapture(active: $capturingHotkey) { keyCode, modifiers in
                        Preferences.hotkeyKeyCode = keyCode
                        Preferences.hotkeyModifiers = modifiers
                        AppState.shared.updateHotkeyDescription()
                        hotkeyDescription = AppState.shared.hotkeyDescription
                        HotkeyManager.shared.register(keyCode: keyCode, modifiers: modifiers)
                        capturingHotkey = false
                    })
                }
            }

            Section("Menu Bar") {
                VStack(alignment: .leading) {
                    Text("Recent items shown in menu: \(Int(maxMenuItems))")
                    Slider(value: $maxMenuItems, in: 5...100, step: 1) {
                        Text("Recent items")
                    } onEditingChanged: { _ in
                        Preferences.maxMenuItems = Int(maxMenuItems)
                    }
                }
            }

            Section("Backup") {
                Toggle("Automatic background export (JSON)", isOn: $autoBackup)
                    .onChange(of: autoBackup) { v in
                        Preferences.autoBackupEnabled = v
                        BackupManager.shared.autoBackupEnabledChanged()
                    }
                HStack {
                    Text("Folder")
                    Spacer()
                    Text(backupFolderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Choose folder…") {
                        if BackupManager.shared.chooseFolder() {
                            backupFolderPath = BackupManager.shared.resolvedFolderPath() ?? "Not set"
                        }
                    }
                    Button("Export now") {
                        let url = BackupManager.shared.exportNow()
                        statusMessage = url.map { "Exported to \($0.lastPathComponent)" }
                            ?? "Export failed"
                    }
                    Button("Import…") {
                        if let n = BackupManager.shared.importFromFile() {
                            statusMessage = "Imported \(n) items"
                            AppState.shared.refresh()
                            dbCount = (try? ClipRepository.shared.count()) ?? 0
                        }
                    }
                }
                Text("Tip: choose a folder inside iCloud Drive, Dropbox, or Google Drive for automatic cloud sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                    Text("Accessibility")
                    Spacer()
                    if accessibilityGranted {
                        Text("Granted").foregroundStyle(.secondary)
                    } else {
                        Button("Request") {
                            PermissionsHelper.requestAccessibility()
                            accessibilityGranted = PermissionsHelper.accessibilityGranted()
                        }
                        Button("Open Settings") {
                            PermissionsHelper.openAccessibilitySettings()
                        }
                    }
                }
                Text("Required to paste into the focused app with Enter. Without it, items are only copied to the clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("CLI") {
                HStack {
                    Text("Install `clip` command into /usr/local/bin")
                    Spacer()
                    Button("Install") {
                        do {
                            try CLIInstaller.install()
                            statusMessage = "Installed at /usr/local/bin/clip"
                        } catch {
                            statusMessage = "Install failed: \(error.localizedDescription)"
                        }
                    }
                }
                Text("Usage: `clip` (open picker), `clip list`, `clip search foo`, `clip 3` (paste 3rd item).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                HStack {
                    Text("Items stored: \(dbCount)")
                    Spacer()
                    Button("Refresh") {
                        dbCount = (try? ClipRepository.shared.count()) ?? 0
                    }
                    Button("Clear unstarred", role: .destructive) {
                        try? ClipRepository.shared.deleteAllUnstarred()
                        AppState.shared.refresh()
                        dbCount = (try? ClipRepository.shared.count()) ?? 0
                    }
                }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .frame(minWidth: 500, minHeight: 480)
        .onAppear {
            accessibilityGranted = PermissionsHelper.accessibilityGranted()
            dbCount = (try? ClipRepository.shared.count()) ?? 0
        }
    }
}

/// Invisible NSView that captures the next keyDown event and reports it
/// as a (keyCode, carbonModifiers) tuple for hotkey rebinding.
struct HotkeyCapture: NSViewRepresentable {
    @Binding var active: Bool
    let onCaptured: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> NSView { CaptureView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? CaptureView else { return }
        v.active = active
        v.onCaptured = onCaptured
    }

    final class CaptureView: NSView {
        var active: Bool = false
        var onCaptured: ((UInt32, UInt32) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                installMonitorIfNeeded()
            } else {
                removeMonitor()
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.active else { return event }
                let mods = HotkeyUtil.carbonModifiers(from: event.modifierFlags)
                guard mods != 0 else { return nil }
                self.onCaptured?(UInt32(event.keyCode), mods)
                return nil
            }
        }

        private func removeMonitor() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        deinit { removeMonitor() }
    }
}
