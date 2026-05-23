import Foundation
import AppKit

final class ClipboardMonitor {
    static let shared = ClipboardMonitor()
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.shailka.SmartClipboard.monitor", qos: .utility)

    /// Fingerprint of the most recent payload *we* placed on the pasteboard.
    /// Used to suppress re-ingestion of our own writes (e.g. after a paste).
    private var ourLastWriteFingerprint: String?

    /// Called on the main thread after a new item is stored.
    var onNewItem: ((ClipItem) -> Void)?

    init() {
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .milliseconds(500),
                   repeating: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Call this BEFORE we set the pasteboard ourselves (during paste-restore),
    /// passing the fingerprint of what we're about to write. The next poll
    /// will skip insertion if the pasteboard still matches.
    func markOwnWrite(fingerprint: String) {
        queue.async {
            self.ourLastWriteFingerprint = fingerprint
        }
    }

    private func poll() {
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc
        guard let item = readPasteboard() else { return }
        let fp = Self.fingerprint(item)
        if fp == ourLastWriteFingerprint {
            // We wrote this. Don't reingest.
            ourLastWriteFingerprint = nil
            return
        }
        do {
            _ = try ClipRepository.shared.insert(item)
            DispatchQueue.main.async { [weak self] in
                self?.onNewItem?(item)
            }
        } catch {
            NSLog("SmartClipboard: insert failed: \(error)")
        }
    }

    static func fingerprint(_ item: ClipItem) -> String {
        switch item.contentType {
        case .text:  return "T:" + (item.textContent ?? "")
        case .image: return "I:\(item.imageData?.count ?? 0):\(item.byteSize)"
        case .files: return "F:" + (item.fileUrls ?? "")
        }
    }

    private func readPasteboard() -> ClipItem? {
        let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let now = Date()
        let types = pasteboard.types ?? []

        // 1. File URLs (strictly file://, so we don't grab http URLs from a browser image copy)
        if types.contains(.fileURL) {
            if let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL], !urls.isEmpty {
                let strs = urls.map(\.absoluteString)
                let json = (try? JSONEncoder().encode(strs))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let preview = urls.map(\.lastPathComponent).joined(separator: ", ")
                let textForSearch = urls.map(\.path).joined(separator: "\n")
                return ClipItem(
                    id: nil,
                    contentType: .files,
                    textContent: textForSearch,
                    imageData: nil,
                    imageThumb: nil,
                    fileUrls: json,
                    preview: String(preview.prefix(200)),
                    byteSize: json.utf8.count,
                    sourceApp: frontApp,
                    isStarred: false,
                    createdAt: now
                )
            }
        }

        // 2. Image — try every known image UTI in priority order.
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.image")
        ]
        if let imageType = pasteboard.availableType(from: imageTypes),
           let rawData = pasteboard.data(forType: imageType),
           !rawData.isEmpty {
            // Re-encode to PNG so storage + thumbnails are predictable.
            let pngData: Data?
            let displayImg: NSImage?
            if imageType == .png || imageType.rawValue == "public.png" {
                pngData = rawData
                displayImg = NSImage(data: rawData)
            } else if let img = NSImage(data: rawData) {
                displayImg = img
                if let tiff = img.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff) {
                    pngData = rep.representation(using: .png, properties: [:])
                } else {
                    pngData = rawData  // fall back to original bytes
                }
            } else {
                pngData = nil
                displayImg = nil
            }

            if let png = pngData, let img = displayImg {
                let thumb = Self.makeThumbnail(image: img, maxDim: 64)
                let w = Int(img.size.width)
                let h = Int(img.size.height)
                let dims = (w > 0 && h > 0) ? "\(w)×\(h)" : "?"
                NSLog("SmartClipboard: captured image \(dims) from type \(imageType.rawValue), \(png.count) bytes")
                return ClipItem(
                    id: nil,
                    contentType: .image,
                    textContent: nil,
                    imageData: png,
                    imageThumb: thumb,
                    fileUrls: nil,
                    preview: "Image \(dims)",
                    byteSize: png.count,
                    sourceApp: frontApp,
                    isStarred: false,
                    createdAt: now
                )
            }
        }

        // 3. Text (last resort — image+text combos prefer image above)
        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            let preview = String(str.prefix(200)).replacingOccurrences(of: "\n", with: " ⏎ ")
            return ClipItem(
                id: nil,
                contentType: .text,
                textContent: str,
                imageData: nil,
                imageThumb: nil,
                fileUrls: nil,
                preview: preview,
                byteSize: str.utf8.count,
                sourceApp: frontApp,
                isStarred: false,
                createdAt: now
            )
        }

        NSLog("SmartClipboard: unrecognized pasteboard, types=\(types.map(\.rawValue))")
        return nil
    }

    private static func makeThumbnail(image: NSImage, maxDim: CGFloat) -> Data? {
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(maxDim / w, maxDim / h, 1)
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
