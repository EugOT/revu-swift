import Foundation
import SQLite3

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteValue: Sendable, Hashable {
    case int64(Int64)
    case text(String)
    case null
}

final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(readOnly url: URL) throws {
        let path = url.path
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let result = sqlite3_open_v2(path, &pointer, flags, nil)
        guard result == SQLITE_OK, let opened = pointer else {
            let message = pointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            if pointer != nil {
                sqlite3_close(pointer)
            }
            throw AnkiImportError.sqliteOpenFailed(message)
        }
        db = opened
        sqlite3_busy_timeout(opened, 1_000)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func query(
        _ sql: String,
        bindings: [SQLiteValue] = [],
        row: (SQLiteRow) throws -> Void
    ) throws {
        guard let db else { throw AnkiImportError.sqliteQueryFailed("Database not open") }
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            throw AnkiImportError.sqliteQueryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            let paramIndex = Int32(index + 1)
            switch value {
            case .int64(let intValue):
                sqlite3_bind_int64(statement, paramIndex, intValue)
            case .text(let stringValue):
                sqlite3_bind_text(statement, paramIndex, stringValue, -1, sqliteTransientDestructor)
            case .null:
                sqlite3_bind_null(statement, paramIndex)
            }
        }

        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW {
                try row(SQLiteRow(statement: statement))
            } else if step == SQLITE_DONE {
                break
            } else {
                throw AnkiImportError.sqliteQueryFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }
}

struct SQLiteRow {
    fileprivate let statement: OpaquePointer

    func int64(_ index: Int) -> Int64 {
        sqlite3_column_int64(statement, Int32(index))
    }

    func int(_ index: Int) -> Int {
        Int(sqlite3_column_int(statement, Int32(index)))
    }

    func double(_ index: Int) -> Double {
        sqlite3_column_double(statement, Int32(index))
    }

    func string(_ index: Int) -> String? {
        guard let cString = sqlite3_column_text(statement, Int32(index)) else {
            return nil
        }
        return String(cString: cString)
    }

    func data(_ index: Int) -> Data? {
        guard let blob = sqlite3_column_blob(statement, Int32(index)) else { return nil }
        let length = Int(sqlite3_column_bytes(statement, Int32(index)))
        return Data(bytes: blob, count: length)
    }
}
