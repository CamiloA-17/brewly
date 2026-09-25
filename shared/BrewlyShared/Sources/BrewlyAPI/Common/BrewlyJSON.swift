import Foundation

/// JSON coders used on both ends of the API: camelCase keys and ISO 8601 dates.
public enum BrewlyJSON {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Current API version prefix.
public enum APIVersion {
    public static let v1 = "v1"
}
