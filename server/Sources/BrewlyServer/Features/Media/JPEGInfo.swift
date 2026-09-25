import Foundation

/// Reads the size of a JPEG image from its header, without decoding the pixels.
enum JPEGInfo {
    /// `nil` when the data is not a JPEG image with a valid frame header.
    static func dimensions(of data: Data) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data)
        guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return nil }
        var index = 2
        while index + 8 < bytes.count {
            guard bytes[index] == 0xFF else { return nil }
            let marker = bytes[index + 1]
            // Fill bytes and markers without a length field.
            if marker == 0xFF {
                index += 1
                continue
            }
            if marker == 0x01 || (0xD0...0xD8).contains(marker) {
                index += 2
                continue
            }
            let length = Int(bytes[index + 2]) << 8 | Int(bytes[index + 3])
            guard length >= 2 else { return nil }
            // Start-of-frame markers (C0–CF except DHT, JPG and DAC) carry the image size.
            if (0xC0...0xCF).contains(marker), ![0xC4, 0xC8, 0xCC].contains(marker) {
                let height = Int(bytes[index + 5]) << 8 | Int(bytes[index + 6])
                let width = Int(bytes[index + 7]) << 8 | Int(bytes[index + 8])
                guard width > 0, height > 0 else { return nil }
                return (width, height)
            }
            index += 2 + length
        }
        return nil
    }
}
