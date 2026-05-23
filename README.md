<div align="center">

<img src="assets/icon-512.png" width="160" alt="Smart Clipboard"/>

# Smart Clipboard

**A native macOS menu-bar clipboard manager.**
Records every text, image, and file you copy into a local SQLite database; re-paste any of them via the menu bar, a global hotkey picker, or a `clip` CLI command.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-1d1d1f?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-2196F3)
![SQLite](https://img.shields.io/badge/SQLite-FTS5-003B57?logo=sqlite&logoColor=white)
[![Latest Release](https://img.shields.io/github/v/release/tech-sumit/SmartClipboard?label=release&color=brightgreen)](https://github.com/tech-sumit/SmartClipboard/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/tech-sumit/SmartClipboard/total?color=blue)](https://github.com/tech-sumit/SmartClipboard/releases)
![License](https://img.shields.io/badge/license-MIT-green)

[**Website**](https://tech-sumit.github.io/SmartClipboard/) · [Download DMG](https://github.com/tech-sumit/SmartClipboard/releases/latest) · [Features](#features) · [Build from source](#build-from-source) · [Design doc](docs/superpowers/specs/2026-05-24-smart-clipboard-design.md)

</div>

---

## Why

The system clipboard holds one thing. Smart Clipboard remembers everything you've ever copied — text, screenshots, files — and lets you re-paste any of it without leaving the keyboard.

- ⚡ **Native Swift/SwiftUI** — single ~5 MB binary, no Electron, no daemon.
- 🔍 **Instant search** — SQLite FTS5 over thousands of items.
- ⭐ **Star items** — pins them forever, surfaces them in the menu.
- ⌨️ **Global hotkey** — default ⌘⇧V, fully rebindable.
- 🖼️ **Images & files** — full thumbnails, file-reference restore.
- 🛠️ **CLI** — `clip 3` from any terminal pastes the 3rd-most-recent item.
- ☁️ **Cloud backup-by-folder** — point the JSON export at an iCloud Drive / Dropbox / Google Drive folder.

---

## Install

### One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/tech-sumit/SmartClipboard/main/scripts/install.sh | bash
```

Downloads the latest DMG, copies the app to `/Applications`, removes the macOS quarantine flag, and launches it. No Gatekeeper dialog.

### Manual DMG install

1. Download `SmartClipboard-x.y.z.dmg` from the [latest release](https://github.com/tech-sumit/SmartClipboard/releases/latest).
2. Open the DMG and drag **Smart Clipboard** into the **Applications** shortcut.
3. **First launch** — because the DMG is ad-hoc signed (no Apple Developer ID notarization), macOS Gatekeeper will say _"Apple could not verify Smart Clipboard is free of malware"_. To bypass:
   - **macOS 14 Sonoma or earlier:** right-click the app in `/Applications` → **Open** → **Open** in the dialog.
   - **macOS 15 Sequoia and later:** double-click (you'll get the warning), then go to **System Settings → Privacy & Security → scroll to "Smart Clipboard was blocked" → Open Anyway**, enter your password.
   - **Or from a terminal** (any macOS version):
     ```bash
     xattr -dr com.apple.quarantine /Applications/SmartClipboard.app
     open /Applications/SmartClipboard.app
     ```
4. Look for the clipboard glyph in your menu bar.

> **Why the friction?** Apple requires a paid Apple Developer Program membership ($99/year) plus notarization for a frictionless install. The v0.1.0 DMG is ad-hoc signed only. Notarized release is on the [roadmap](#roadmap-v2-ideas).

### Build from source

You need Xcode 14+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/tech-sumit/SmartClipboard.git
cd SmartClipboard
xcodegen generate
open SmartClipboard.xcodeproj   # then ⌘R
```

…or fully from the command line:

```bash
xcodebuild -project SmartClipboard.xcodeproj \
           -scheme SmartClipboard \
           -configuration Release \
           -derivedDataPath .build build
cp -R .build/Build/Products/Release/SmartClipboard.app /Applications/
open /Applications/SmartClipboard.app
```

---

## First-Run Permissions

The app needs two macOS permissions for full functionality:

| Permission | Why | Triggered by |
|------------|-----|--------------|
| **Accessibility** | Synthesize ⌘V into the focused app on Enter | Settings → Permissions → "Request" |
| **Input Monitoring** | Global hotkey (⌘⇧V) | First time the hotkey fires |

Without **Accessibility**, the picker still works — it just restores items to the clipboard so you can press ⌘V yourself.

---

## Features

### Menu bar dropdown

```
┌─────────────────────────────────┐
│ Smart Clipboard                 │
├─────────────────────────────────┤
│ Open Picker  ⌘⇧V                │
├─────────────────────────────────┤
│ Starred                         │
│ ★ TODO: refactor auth module    │
│ ★ git rebase -i HEAD~5          │
├─────────────────────────────────┤
│ Recent                          │
│ 1  https://news.ycombinator.com │
│ 2  📷 Image 1920×1080           │
│ 3  📂 Screenshot 2026-05-24.png │
│ 4  npm run dev                  │
│ 5  ssh me@10.0.0.42             │
│ …                               │
├─────────────────────────────────┤
│ Clear Unstarred History         │
│ Settings…                  ⌘,   │
│ Quit Smart Clipboard       ⌘Q   │
└─────────────────────────────────┘
```

- Click any item → restores it AND pastes into the previously focused app.
- **Option-click** → restore only (no paste).
- Top 9 items get **⌘1 … ⌘9** hotkeys inside the menu.

### Global hotkey picker (⌘⇧V)

```
┌──────────────────────────────────────────────────┐
│ 🔍 git rebase                              42    │
├──────────────────────────────────────────────────┤
│ 📄 git rebase -i HEAD~5         TEXT  iTerm 2m   │
│ 📄 git rebase --autostash       TEXT  iTerm 8m   │
│ 📄 git rebase --onto main …     TEXT  Code  1h   │
├──────────────────────────────────────────────────┤
│ ↩ Paste   ⌥↩ Copy only   ⎋ Close  ⌘F ⭐  ⌘⌫ ✕    │
└──────────────────────────────────────────────────┘
```

- Spotlight-style search (SQLite FTS5, fuzzy prefix match on text + file names).
- **↑ / ↓** navigate, **↩** paste, **⌥↩** copy without pasting.
- **⌘F** star/unstar, **⌘⌫** delete, **⎋** close.
- Non-activating panel — the app you came from keeps keyboard focus.

### `clip` command-line tool

```
$ clip list
1  42  ★  TODO: refactor auth module
2  41     git rebase -i HEAD~5
3  39     https://news.ycombinator.com
4  38     npm run dev
…

$ clip search rebase
1  41     git rebase -i HEAD~5
2  37     git rebase --autostash

$ clip 2
# pastes "git rebase -i HEAD~5" into the current terminal
```

Install from **Settings → CLI → Install** (symlinks to `/usr/local/bin/clip`, or `~/bin/clip` if the former isn't writable).

### Backup & cloud sync (via folder)

- **Settings → Backup → Choose folder** picks a destination.
- **Export Now** writes `smartclipboard-backup.json` (streamed — won't OOM with thousands of images).
- **Auto-export**: rewrites the file 30 s after the last clipboard change.
- For free cloud sync, point the folder at:
  - `~/Library/Mobile Documents/com~apple~CloudDocs/` → iCloud Drive
  - `~/Dropbox/SmartClipboard/` → Dropbox
  - `~/Google Drive/SmartClipboard/` → Google Drive

---

## How it works

### Architecture

```mermaid
flowchart LR
    classDef ext fill:#f4f4f8,stroke:#999,stroke-dasharray:3 3,color:#222
    classDef core fill:#eef0ff,stroke:#5E63FF,color:#1d1d1f
    classDef store fill:#dde0ff,stroke:#3437C9,stroke-width:2px,color:#1d1d1f

    PB["NSPasteboard<br/>(system clipboard)"]:::ext
    KEY["⌘⇧V hotkey"]:::ext
    CLI["clip CLI"]:::ext
    SI["NSStatusItem<br/>(menu bar)"]:::ext
    APP["Focused app"]:::ext
    DB[("SQLite + FTS5<br/>~/Library/Application Support/")]:::ext
    CLOUD[("Folder<br/>iCloud / Dropbox / Drive")]:::ext

    subgraph SC ["SmartClipboard.app — single process, LSUIElement"]
        CM["ClipboardMonitor<br/>0.5s poll"]:::core
        HM["HotkeyManager<br/>Carbon RegisterEventHotKey"]:::core
        UH["URLSchemeHandler<br/>smartclipboard://..."]:::core
        MC["MenuBarController<br/>NSMenu rendering"]:::core
        PP["PickerPanel<br/>non-activating NSPanel"]:::core
        PA["Paster<br/>CGEventPost ⌘V"]:::core
        BM["BackupManager<br/>streamed JSON"]:::core
        CR{{"ClipRepository<br/>CRUD + dedup + FTS5"}}:::store
    end

    PB -- "poll changeCount" --> CM --> CR
    KEY --> HM --> PP --> CR
    CLI -- "open URL" --> UH --> CR
    SI --> MC --> CR
    PP --> PA --> APP
    CR <--> DB
    CR --> BM --> CLOUD
```

### Capture-and-paste flow

```mermaid
sequenceDiagram
    autonumber
    actor U as You
    participant SP as System Pasteboard
    participant CM as ClipboardMonitor
    participant DB as SQLite + FTS5
    participant HK as HotkeyManager
    participant PP as PickerPanel
    participant PR as Paster
    participant App as Focused app

    rect rgba(94,99,255,0.08)
    Note over U,App: Capture (continuous)
    U->>SP: ⌘C (copy)
    CM->>SP: poll every 500 ms
    CM->>CM: payload != self-write fingerprint?
    CM->>DB: INSERT (dedup against latest row)
    end

    rect rgba(94,99,255,0.08)
    Note over U,App: Recall + paste
    U->>HK: ⌘⇧V
    HK->>PP: show() — capture frontmost app
    PP->>DB: FTS5 search as you type
    DB-->>PP: matching ClipItems
    U->>PP: ↩ on item
    PP->>PR: restoreAndPaste(item, activating: App)
    PR->>CM: mark own write (fingerprint)
    PR->>SP: clearContents + setString/Image
    PR->>App: activate
    Note over PR,App: poll isActive up to 200 ms
    PR->>App: CGEventPost ⌘V
    App->>SP: read content
    end
```

### Implementation notes

- **Storage:** `~/Library/Application Support/SmartClipboard/clipboard.sqlite` (single file, WAL-mode SQLite + FTS5 virtual table).
- **Dedup:** identical-to-previous payload bumps `created_at` instead of inserting.
- **Self-write suppression:** when we restore an item, the monitor records a fingerprint and skips it on the next poll.
- **No daemon:** the `clip` CLI calls `open smartclipboard://...` — the running app handles the URL via `NSApplicationDelegate.application(_:open:)`.
- **Streamed backup:** auto-export reads rows 50 at a time and writes incrementally to a temp file, then atomically renames — peak memory stays small even with thousands of multi-MB images.

---

## Known Tradeoffs

- **Captures everything**, including passwords copied from password managers. Items flagged `org.nspasteboard.ConcealedType` are **not** filtered. The SQLite DB is unencrypted at rest. Don't auto-export to a public folder.
- **Unlimited history** — storage grows over time. Use **Settings → Data → Clear unstarred** to prune.
- The release DMG is **ad-hoc signed**, not Developer-ID-notarized. macOS Gatekeeper will refuse a normal double-click; right-click → **Open** the first time.

---

## Manual Test Checklist

- [ ] Copy text from anywhere → appears in menu bar dropdown.
- [ ] Copy an image (⌘⇧4) → appears with thumbnail.
- [ ] Copy files in Finder → appears with folder icon.
- [ ] ⌘⇧V → picker opens; previous app keeps focus.
- [ ] Type to search; ↑↓ to navigate; ↩ pastes into the previously focused app.
- [ ] ⌥↩ → copies without pasting.
- [ ] ⌘F → star/unstar; ⌘⌫ → delete.
- [ ] Quit & relaunch → history persists, hotkey re-registers.
- [ ] Settings → rebind hotkey → new hotkey works immediately.
- [ ] Settings → Backup → Choose folder → Export Now → JSON appears.
- [ ] Settings → CLI → Install → `clip list` prints items.
- [ ] `clip 1` pastes the most-recent item into the terminal.

---

## Project layout

```
SmartClipboard/
├── project.yml                       # XcodeGen config
├── docs/superpowers/specs/           # design doc
├── assets/                           # icon SVG + iconset + icns
├── bin/clip                          # CLI shell script
└── SmartClipboard/
    ├── SmartClipboardApp.swift       # @main, AppDelegate
    ├── AppState.swift                # ObservableObject
    ├── Preferences.swift             # UserDefaults wrapper
    ├── CLIInstaller.swift            # /usr/local/bin/clip symlink
    ├── Models/ClipItem.swift
    ├── Storage/Database.swift        # GRDB + migrations + FTS5
    ├── Storage/ClipRepository.swift  # CRUD + search + dedup
    ├── Clipboard/ClipboardMonitor.swift
    ├── Clipboard/Paster.swift
    ├── Hotkey/HotkeyManager.swift    # Carbon RegisterEventHotKey
    ├── URLScheme/URLSchemeHandler.swift
    ├── Permissions/PermissionsHelper.swift
    ├── Backup/BackupManager.swift    # streamed JSON export
    └── UI/
        ├── MenuBarController.swift
        ├── PickerPanel.swift         # non-activating NSPanel
        ├── PickerView.swift
        ├── ItemRow.swift
        └── SettingsView.swift
```

---

## Roadmap (v2 ideas)

- CloudKit sync of starred items across Macs.
- Native Google Drive (OAuth + Drive API) sync.
- Optional rich-text / RTF capture.
- Categories / tags / snippet templates.
- Opt-in `ConcealedType` filtering.
- AES-encrypted DB at rest with passphrase.
- Developer-ID-signed & notarized DMG.

---

## License

MIT. See [`LICENSE`](LICENSE).

## Credits

- Built with [GRDB.swift](https://github.com/groue/GRDB.swift) for SQLite + FTS5.
- Project scaffolding via [XcodeGen](https://github.com/yonaskolb/XcodeGen).
