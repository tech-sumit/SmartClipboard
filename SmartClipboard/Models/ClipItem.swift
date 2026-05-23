import Foundation
import GRDB
import AppKit

enum ClipContentType: String, Codable {
    case text
    case image
    case files
}

struct ClipItem: Identifiable, Codable, Equatable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var contentType: ClipContentType
    var textContent: String?
    var imageData: Data?
    var imageThumb: Data?
    var fileUrls: String?    // JSON-encoded [String]
    var preview: String
    var byteSize: Int
    var sourceApp: String?
    var isStarred: Bool
    var createdAt: Date

    static let databaseTableName = "clip_items"

    enum Columns {
        static let id = Column("id")
        static let contentType = Column("content_type")
        static let textContent = Column("text_content")
        static let imageData = Column("image_data")
        static let imageThumb = Column("image_thumb")
        static let fileUrls = Column("file_urls")
        static let preview = Column("preview")
        static let byteSize = Column("byte_size")
        static let sourceApp = Column("source_app")
        static let isStarred = Column("is_starred")
        static let createdAt = Column("created_at")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contentType = "content_type"
        case textContent = "text_content"
        case imageData = "image_data"
        case imageThumb = "image_thumb"
        case fileUrls = "file_urls"
        case preview
        case byteSize = "byte_size"
        case sourceApp = "source_app"
        case isStarred = "is_starred"
        case createdAt = "created_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    var fileURLList: [URL] {
        guard let s = fileUrls, let data = s.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr.compactMap { URL(string: $0) }
    }

    var thumbnailImage: NSImage? {
        guard let d = imageThumb else { return nil }
        return NSImage(data: d)
    }

    var fullImage: NSImage? {
        guard let d = imageData else { return nil }
        return NSImage(data: d)
    }
}
