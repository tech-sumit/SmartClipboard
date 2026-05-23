import Foundation
import GRDB
import AppKit

final class ClipRepository {
    static let shared = ClipRepository()
    private let pool: DatabasePool

    init(pool: DatabasePool = AppDatabase.shared) {
        self.pool = pool
    }

    // MARK: - Insert / dedup

    /// Insert a new item, deduplicating against the most-recent entry.
    /// If identical, bumps `createdAt` and returns the existing row id.
    @discardableResult
    func insert(_ item: ClipItem) throws -> Int64 {
        try pool.write { db in
            // Dedup against the most-recent row
            if let last = try ClipItem
                .order(ClipItem.Columns.createdAt.desc)
                .fetchOne(db),
               last.contentType == item.contentType,
               Self.payloadEqual(last, item) {
                try db.execute(
                    sql: "UPDATE clip_items SET created_at = ? WHERE id = ?",
                    arguments: [Date(), last.id]
                )
                return last.id ?? 0
            }
            var mutable = item
            try mutable.insert(db)
            return mutable.id ?? 0
        }
    }

    private static func payloadEqual(_ a: ClipItem, _ b: ClipItem) -> Bool {
        switch a.contentType {
        case .text:  return a.textContent == b.textContent
        case .image: return a.imageData == b.imageData
        case .files: return a.fileUrls == b.fileUrls
        }
    }

    // MARK: - Fetch

    func recent(limit: Int) throws -> [ClipItem] {
        try pool.read { db in
            try ClipItem
                .order(ClipItem.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func page(limit: Int, offset: Int) throws -> [ClipItem] {
        try pool.read { db in
            try ClipItem
                .order(ClipItem.Columns.createdAt.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    func starred() throws -> [ClipItem] {
        try pool.read { db in
            try ClipItem
                .filter(ClipItem.Columns.isStarred == true)
                .order(ClipItem.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    func fetch(id: Int64) throws -> ClipItem? {
        try pool.read { db in try ClipItem.fetchOne(db, key: id) }
    }

    func search(_ query: String, limit: Int = 200) throws -> [ClipItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return try recent(limit: limit) }
        return try pool.read { db in
            // Build a safe FTS query: split tokens and append * for prefix matching
            let tokens = trimmed.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            let ftsQuery = tokens.map { "\($0)*" }.joined(separator: " ")
            guard !ftsQuery.isEmpty else { return [] }
            let sql = """
                SELECT clip_items.* FROM clip_items
                JOIN clip_items_fts ON clip_items_fts.rowid = clip_items.id
                WHERE clip_items_fts MATCH ?
                ORDER BY clip_items.created_at DESC
                LIMIT ?
                """
            return try ClipItem.fetchAll(db, sql: sql, arguments: [ftsQuery, limit])
        }
    }

    // MARK: - Mutate

    func toggleStar(id: Int64) throws {
        _ = try pool.write { db in
            try db.execute(
                sql: "UPDATE clip_items SET is_starred = NOT is_starred WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func delete(id: Int64) throws {
        _ = try pool.write { db in
            try ClipItem.deleteOne(db, key: id)
        }
    }

    func deleteAllUnstarred() throws {
        _ = try pool.write { db in
            try db.execute(sql: "DELETE FROM clip_items WHERE is_starred = 0")
        }
    }

    func deleteAll() throws {
        _ = try pool.write { db in
            try db.execute(sql: "DELETE FROM clip_items")
        }
    }

    func touch(id: Int64) throws {
        _ = try pool.write { db in
            try db.execute(
                sql: "UPDATE clip_items SET created_at = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }

    func count() throws -> Int {
        try pool.read { db in try ClipItem.fetchCount(db) }
    }
}
