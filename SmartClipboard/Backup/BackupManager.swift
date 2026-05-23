import Foundation
import AppKit

/// JSON export/import + automatic background backup to a user-chosen folder.
final class BackupManager {
    static let shared = BackupManager()

    private var folderURL: URL?
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.shailka.SmartClipboard.backup", qos: .utility)

    init() {
        folderURL = resolveBookmark()
    }

    // MARK: - Public

    func resolvedFolderPath() -> String? { folderURL?.path }

    func chooseFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose backup folder"
        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(url: url)
            folderURL = url
            return true
        }
        return false
    }

    func clipChanged() {
        guard Preferences.autoBackupEnabled, folderURL != nil else { return }
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.exportNow() }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + 30, execute: work)
    }

    func autoBackupEnabledChanged() {
        if Preferences.autoBackupEnabled, folderURL == nil {
            _ = chooseFolder()
        }
    }

    @discardableResult
    func exportNow() -> URL? {
        guard let folder = folderURL else { return nil }
        let needsScope = folder.startAccessingSecurityScopedResource()
        defer { if needsScope { folder.stopAccessingSecurityScopedResource() } }
        do {
            let target = folder.appendingPathComponent("smartclipboard-backup.json")
            let tmp = folder.appendingPathComponent("smartclipboard-backup.json.tmp")

            // Stream-encode to avoid holding every image blob in memory.
            FileManager.default.createFile(atPath: tmp.path, contents: nil)
            guard let handle = try? FileHandle(forWritingTo: tmp) else { return nil }
            defer { try? handle.close() }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try handle.write(contentsOf: Data("[\n".utf8))

            let batchSize = 50
            var offset = 0
            var first = true
            while true {
                let batch = try ClipRepository.shared.page(limit: batchSize, offset: offset)
                if batch.isEmpty { break }
                for item in batch {
                    let export = ExportItem.from(item)
                    let data = try encoder.encode(export)
                    if !first { try handle.write(contentsOf: Data(",\n".utf8)) }
                    try handle.write(contentsOf: data)
                    first = false
                }
                offset += batch.count
                if batch.count < batchSize { break }
            }
            try handle.write(contentsOf: Data("\n]\n".utf8))
            try handle.close()

            // Atomic rename
            _ = try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: tmp, to: target)
            return target
        } catch {
            NSLog("SmartClipboard: export failed: \(error)")
            return nil
        }
    }

    /// Returns number of items imported, or nil if cancelled / failed.
    func importFromFile() -> Int? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exports = try decoder.decode([ExportItem].self, from: data)
            var imported = 0
            for e in exports {
                let item = e.toClipItem()
                _ = try ClipRepository.shared.insert(item)
                imported += 1
            }
            return imported
        } catch {
            NSLog("SmartClipboard: import failed: \(error)")
            return nil
        }
    }

    // MARK: - Bookmarks

    private func saveBookmark(url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
            Preferences.backupFolderBookmark = data
        } catch {
            // Fall back to plain bookmark (no security scope) so we still remember the path.
            if let data = try? url.bookmarkData() {
                Preferences.backupFolderBookmark = data
            }
            NSLog("SmartClipboard: bookmark save failed: \(error)")
        }
    }

    private func resolveBookmark() -> URL? {
        guard let data = Preferences.backupFolderBookmark else { return nil }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale)
            return url
        } catch {
            return try? URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale)
        }
    }
}

// MARK: - On-disk JSON representation

private struct ExportItem: Codable {
    var id: Int64?
    var contentType: String
    var textContent: String?
    var imageBase64: String?
    var fileUrls: [String]?
    var preview: String
    var byteSize: Int
    var sourceApp: String?
    var isStarred: Bool
    var createdAt: Date

    static func from(_ item: ClipItem) -> ExportItem {
        ExportItem(
            id: item.id,
            contentType: item.contentType.rawValue,
            textContent: item.textContent,
            imageBase64: item.imageData?.base64EncodedString(),
            fileUrls: item.fileURLList.map(\.absoluteString),
            preview: item.preview,
            byteSize: item.byteSize,
            sourceApp: item.sourceApp,
            isStarred: item.isStarred,
            createdAt: item.createdAt
        )
    }

    func toClipItem() -> ClipItem {
        let type = ClipContentType(rawValue: contentType) ?? .text
        let imgData = imageBase64.flatMap { Data(base64Encoded: $0) }
        var thumb: Data? = nil
        if let imgData, let nsimg = NSImage(data: imgData) {
            thumb = BackupManager.makeThumb(image: nsimg)
        }
        let urlsJSON: String? = {
            guard let arr = fileUrls else { return nil }
            return (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
        }()
        return ClipItem(
            id: nil,
            contentType: type,
            textContent: textContent,
            imageData: imgData,
            imageThumb: thumb,
            fileUrls: urlsJSON,
            preview: preview,
            byteSize: byteSize,
            sourceApp: sourceApp,
            isStarred: isStarred,
            createdAt: createdAt
        )
    }
}

private extension BackupManager {
    static func makeThumb(image: NSImage) -> Data? {
        let w = image.size.width
        let h = image.size.height
        let scale = min(64 / w, 64 / h, 1)
        let newSize = NSSize(width: w * scale, height: h * scale)
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
