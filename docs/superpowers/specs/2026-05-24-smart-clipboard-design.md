# Smart Clipboard — Design

**Date:** 2026-05-24
**Status:** Approved (user requested direct-to-implementation)

## Summary
A native macOS menu-bar app written in Swift/SwiftUI that records every clipboard change to a local SQLite database and lets the user re-paste any past item via the menu bar, a global hotkey picker, or a `clip` CLI command. Starred items are preserved indefinitely. Settings allow exporting/importing the full database as JSON to a chosen folder (the user can point that folder at iCloud Drive, Dropbox, or a Google Drive sync folder for free cloud backup).

## Goals (v1)
1. Zero-loss clipboard history for **text, images, and file references**, stored in SQLite.
2. **Menu bar item** showing the most recent items, with search and click-to-restore-and-paste.
3. **Global hotkey** (default ⌘⇧V, user-rebindable) that opens a search picker; Enter restores the item and pastes into the previously focused app.
4. **Star / unstar** items; starred items never get evicted (no automatic eviction in v1; unlimited history per user choice).
5. **`clip` CLI** for terminal use (`clip list`, `clip search foo`, `clip 3` to paste-by-index). Implemented as a thin shell wrapper that invokes the main app via `smartclipboard://` URL scheme — no separate background process.
6. **Settings**: hotkey, exclude list, manual export, automatic background export to a chosen folder.

## Non-goals (v1)
- iCloud / CloudKit sync (user can point export folder at iCloud Drive for the same effect).
- Google Drive OAuth integration (same workaround).
- Rich text / HTML capture.
- Multi-device sync over the network.

## Architecture
Single Swift/SwiftUI macOS process. One Xcode target. No daemon, no helper apps.

- **Process model:** Foreground LSUIElement app (no Dock icon, menu bar only). Launches at login (optional, off by default).
- **UI framework:** SwiftUI for the settings window and picker contents; `NSStatusItem` + `NSMenu` for the menu bar to keep full control over click behavior; `NSPanel` (non-activating, floating) hosts the SwiftUI picker so the previously-focused app keeps key-focus.
- **Storage:** SQLite via GRDB.swift (SPM dependency). Single DB file at `~/Library/Application Support/SmartClipboard/clipboard.sqlite`. FTS5 virtual table for fuzzy search.
- **Clipboard capture:** `NSPasteboard.general.changeCount` polled every 0.5 s on a background queue.
- **Paste simulation:** `CGEventPost` synthesizes ⌘V into the previously focused app (requires Accessibility permission).
- **Global hotkey:** Carbon `RegisterEventHotKey` (no third-party dependency).
- **CLI:** `clip` shell script in `bin/clip`, optionally symlinked into `/usr/local/bin` from Settings. It calls `open "smartclipboard://..."` which the app handles via `NSApplicationDelegateAdaptor`'s URL handler.

## Data model

```sql
CREATE TABLE clip_items (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  content_type  TEXT    NOT NULL,        -- 'text' | 'image' | 'files'
  text_content  TEXT,                    -- text body, or newline-joined file paths
  image_data    BLOB,                    -- PNG bytes for content_type='image'
  image_thumb   BLOB,                    -- 64px PNG thumbnail
  file_urls     TEXT,                    -- JSON array of file:// URLs for 'files'
  preview       TEXT    NOT NULL,        -- short string shown in menu/picker
  byte_size     INTEGER NOT NULL,
  source_app    TEXT,                    -- bundle id of frontmost app at copy time
  is_starred    INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL         -- unix epoch seconds
);

CREATE INDEX idx_clip_items_created  ON clip_items(created_at DESC);
CREATE INDEX idx_clip_items_starred  ON clip_items(is_starred);

CREATE VIRTUAL TABLE clip_items_fts USING fts5(
  preview, text_content,
  content='clip_items', content_rowid='id'
);
-- INSERT/UPDATE/DELETE triggers keep clip_items_fts in sync.
```

Dedup: when a new pasteboard payload is identical to the most-recent item (same content_type + byte-equal payload), bump its `created_at` instead of inserting a duplicate row.

## Component map

| File | Responsibility |
|------|---------------|
| `SmartClipboardApp.swift` | `@main`, `AppDelegate`, scene setup, URL handling |
| `AppState.swift` | App-wide `@Observable` state (items, search, settings) |
| `Models/ClipItem.swift` | Codable / GRDB record |
| `Storage/Database.swift` | GRDB pool, migrations, FTS triggers |
| `Storage/ClipRepository.swift` | CRUD + search + dedup |
| `Clipboard/ClipboardMonitor.swift` | NSPasteboard change-count polling |
| `Clipboard/Paster.swift` | Restore item to pasteboard + simulate ⌘V |
| `Hotkey/HotkeyManager.swift` | Carbon `RegisterEventHotKey` wrapper |
| `URLScheme/URLSchemeHandler.swift` | Parse `smartclipboard://` URLs from the CLI |
| `UI/MenuBarController.swift` | NSStatusItem + NSMenu rendering of recent items |
| `UI/PickerPanel.swift` | NSPanel + NSHostingView wrapper for the picker |
| `UI/PickerView.swift` | SwiftUI picker (search field + list + keyboard nav) |
| `UI/SettingsView.swift` | SwiftUI settings (hotkey, export, CLI install) |
| `Backup/BackupManager.swift` | JSON export/import; debounced auto-export on changes |
| `Permissions/PermissionsHelper.swift` | Accessibility check + open System Settings deep-link |
| `Preferences.swift` | UserDefaults wrapper |
| `bin/clip` | Shell wrapper that calls `open smartclipboard://...` |

## Permissions
Requested only when needed, with an in-app explanation before triggering the OS prompt.

- **Accessibility (`AXIsProcessTrusted`)** — required to synthesize ⌘V into the focused app. Without it, the picker still works but only sets the clipboard; the user must press ⌘V themselves.
- **Input Monitoring** — implicit via Carbon hotkey registration; macOS will prompt the first time.
- **Full Disk Access** — not required.
- **App Sandbox** — disabled (clipboard + accessibility require unsandboxed access).

## User-acknowledged tradeoffs
- **Unlimited history**: storage grows unbounded. Future: configurable cap with starred-item exclusion.
- **No password redaction**: items flagged `org.nspasteboard.ConcealedType` or `org.nspasteboard.TransientType` (used by 1Password, Bitwarden, Keychain Access) **will be captured** to the SQLite DB in cleartext per user request. Documented in README as a known privacy tradeoff. Future: optional opt-in to honor these flags.

## Backup
- Single JSON file containing every row (text inlined, images base64-encoded).
- Manual "Export Now" button.
- Automatic background export: debounced 30 s after the last clipboard change, written atomically to the chosen folder. User can choose `~/Library/Mobile Documents/com~apple~CloudDocs/SmartClipboard/` for iCloud, or any Google Drive / Dropbox sync folder.
- Import: replaces or merges the current DB (user-chosen).

## Open follow-ups (deferred to v2)
- CloudKit sync for cross-device starred items.
- Google Drive native OAuth + Drive API upload.
- Optional rich-text capture.
- Pinned categories (Snippets) separate from time-ordered history.
- Tag/color labels.
- AES encryption at rest with a passphrase.

## Testing approach
The user will test the app in Xcode after the implementation is complete. Manual test checklist will be provided in the README.
