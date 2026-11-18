import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Readies picture data for a note: images sync through iCloud with the note,
/// so large ones are shrunk and unusual formats re-encoded.
nonisolated enum NoteImage {
    /// The longest side, in pixels, an image keeps in a note.
    static let maxPixelSize = 2048
    /// Images up to this size in a common format are stored byte for byte.
    static let maxUnchangedBytes = 1_500_000
    static let jpegQuality = 0.85

    private static let keptTypes: Set<String> = [
        UTType.png.identifier, UTType.jpeg.identifier, UTType.gif.identifier, UTType.heic.identifier,
    ]

    /// The data to store for an image, or `nil` when `data` isn't an image.
    static func prepared(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }

        let type = CGImageSourceGetType(source) as String?
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let longestSide = max(width, height)
        if longestSide <= maxPixelSize, data.count <= maxUnchangedBytes, orientation == 1,
           let type, keptTypes.contains(type) {
            return data
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixelSize, longestSide),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(image)
    }

    /// PNG keeps transparency; everything else becomes a JPEG.
    private static func encode(_ image: CGImage) -> Data? {
        let opaque: Set<CGImageAlphaInfo> = [.none, .noneSkipFirst, .noneSkipLast]
        let hasAlpha = !opaque.contains(image.alphaInfo)
        let type = hasAlpha ? UTType.png : .jpeg
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = hasAlpha ? [:] : [kCGImageDestinationLossyCompressionQuality: jpegQuality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
