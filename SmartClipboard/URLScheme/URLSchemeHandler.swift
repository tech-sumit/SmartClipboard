import Foundation
import AppKit

/// Handles `smartclipboard://...` URLs invoked by the `clip` CLI.
///
/// Supported URLs:
///   smartclipboard://paste?id=<n>            — restore item <n> and synth ⌘V
///   smartclipboard://copy?id=<n>             — restore item <n> to clipboard (no paste)
///   smartclipboard://show                    — show the picker
///   smartclipboard://list                    — print recent items to a stdout file (used by CLI)
///   smartclipboard://search?q=<text>         — same, filtered
enum URLSchemeHandler {
    static func handle(_ url: URL) {
        guard url.scheme == "smartclipboard" else { return }
        let host = url.host ?? ""
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let qs = Dictionary(uniqueKeysWithValues:
            (comps?.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        switch host {
        case "paste":
            guard let idStr = qs["id"], let id = Int64(idStr),
                  let item = try? ClipRepository.shared.fetch(id: id)
            else { return }
            Paster.restoreAndPaste(item)

        case "copy":
            guard let idStr = qs["id"], let id = Int64(idStr),
                  let item = try? ClipRepository.shared.fetch(id: id)
            else { return }
            Paster.restore(item)

        case "show":
            DispatchQueue.main.async {
                PickerPanel.shared.toggle()
            }

        case "list":
            writeListToFile(query: nil, outputPath: qs["out"])

        case "search":
            writeListToFile(query: qs["q"], outputPath: qs["out"])

        default:
            break
        }
    }

    private static func writeListToFile(query: String?, outputPath: String?) {
        guard let outputPath, !outputPath.isEmpty else { return }
        do {
            let items: [ClipItem]
            if let q = query, !q.isEmpty {
                items = try ClipRepository.shared.search(q, limit: 50)
            } else {
                items = try ClipRepository.shared.recent(limit: 50)
            }
            var lines: [String] = []
            for (idx, item) in items.enumerated() {
                let star = item.isStarred ? "★" : " "
                let id = item.id ?? 0
                lines.append("\(idx + 1)\t\(id)\t\(star)\t\(item.preview)")
            }
            try lines.joined(separator: "\n").write(
                toFile: outputPath, atomically: true, encoding: .utf8)
        } catch {
            NSLog("SmartClipboard: list write failed: \(error)")
        }
    }
}
