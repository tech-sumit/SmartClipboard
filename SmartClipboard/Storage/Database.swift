import Foundation
import GRDB

enum AppDatabase {
    static let shared: DatabasePool = {
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("SmartClipboard", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbURL = dir.appendingPathComponent("clipboard.sqlite")

            var config = Configuration()
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode = WAL")
            }
            let pool = try DatabasePool(path: dbURL.path, configuration: config)
            try migrator.migrate(pool)
            return pool
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }()

    static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()

        m.registerMigration("v1_create_clip_items") { db in
            try db.create(table: "clip_items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content_type", .text).notNull()
                t.column("text_content", .text)
                t.column("image_data", .blob)
                t.column("image_thumb", .blob)
                t.column("file_urls", .text)
                t.column("preview", .text).notNull()
                t.column("byte_size", .integer).notNull().defaults(to: 0)
                t.column("source_app", .text)
                t.column("is_starred", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_clip_items_created",
                          on: "clip_items", columns: ["created_at"])
            try db.create(index: "idx_clip_items_starred",
                          on: "clip_items", columns: ["is_starred"])
        }

        m.registerMigration("v2_fts") { db in
            try db.create(virtualTable: "clip_items_fts", using: FTS5()) { t in
                t.synchronize(withTable: "clip_items")
                t.tokenizer = .unicode61()
                t.column("preview")
                t.column("text_content")
            }
        }

        return m
    }
}
