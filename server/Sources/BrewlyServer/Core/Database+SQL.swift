import FluentKit
import SQLKit
import Vapor

extension Database {
    /// The SQLKit view of a Fluent PostgreSQL database.
    var sql: any SQLDatabase {
        guard let sql = self as? any SQLDatabase else {
            fatalError("The configured database does not support raw SQL.")
        }
        return sql
    }
}

extension SQLRow {
    /// Decodes a row into a `Decodable` model whose properties are the camelCase
    /// version of the selected snake_case column names.
    func decodeSnakeCase<Model: Decodable>(_ type: Model.Type) throws -> Model {
        try decode(model: type, keyDecodingStrategy: .convertFromSnakeCase)
    }
}

extension String {
    /// Trimmed text, or `nil` when blank. Used to normalize optional request fields.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Optional where Wrapped == String {
    var nilIfBlank: String? { self?.nilIfBlank }
}

extension Array where Element: Hashable {
    /// The array without duplicates, keeping the first occurrence.
    var uniqued: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
