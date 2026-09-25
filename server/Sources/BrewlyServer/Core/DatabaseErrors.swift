import PostgresNIO

/// Helpers to recognize PostgreSQL constraint violations by SQLSTATE.
extension PSQLError {
    var sqlState: String? { serverInfo?[.sqlState] }
    var constraintName: String? { serverInfo?[.constraintName] }

    var isUniqueViolation: Bool { sqlState == "23505" }
    var isForeignKeyViolation: Bool { sqlState == "23503" }
    var isCheckViolation: Bool { sqlState == "23514" }
}

extension Error {
    /// The PostgreSQL error, when this error comes from the database.
    var postgresError: PSQLError? { self as? PSQLError }
}
