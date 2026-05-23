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

[Download DMG](https://github.com/tech-sumit/SmartClipboard/releases/latest) · [Features](#features) · [Build from source](#build-from-source) · [Design doc](docs/superpowers/specs/2026-05-24-smart-clipboard-design.md)

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

### From DMG (recommended)

1. Download `SmartClipboard-x.y.z.dmg` from the [latest release](https://github.com/tech-sumit/SmartClipboard/releases/latest).
2. Open the DMG; drag **Smart Clipboard** into **Applications**.
3. First launch: **right-click the app → Open** (the DMG is ad-hoc signed; Gatekeeper will refuse a normal double-click).
4. Look for the clipboard glyph in your menu bar.

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

```
                    ┌────────────────────────────────────┐
                    │           SmartClipboard.app       │
                    │  (LSUIElement, single process)     │
                    │                                    │
NSPasteboard ──poll──▶ ClipboardMonitor                  │
                    │       │                            │
                    │       ▼                            │
                    │  ClipRepository ──▶ GRDB ──▶ SQLite│
                    │       ▲                  + FTS5    │
   ⌘⇧V  ──Carbon───▶ HotkeyManager ──▶ PickerPanel       │
                    │                       │            │
   clip CLI ──URL──▶ URLSchemeHandler ──────┘            │
                    │                                    │
                    │  MenuBarController ◀── NSStatusItem│
                    │                                    │
                    │  Paster ──CGEventPost──▶ ⌘V into   │
                    │                          focused app│
                    │                                    │
                    │  BackupManager ──streamed JSON──▶  │
                    │                       chosen folder│
                    └────────────────────────────────────┘
```

- **Storage:** `~/Library/Application Support/SmartClipboard/clipboard.sqlite` (single file, WAL-mode SQLite + FTS5 virtual table).
- **Dedup:** identical-to-previous payload bumps `created_at` instead of inserting.
- **Self-write suppression:** when we restore an item, the monitor records a fingerprint and skips it on the next poll.
- **No daemon:** the `clip` CLI calls `open smartclipboard://...` — the running app handles the URL.

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
