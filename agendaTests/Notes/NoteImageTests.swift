import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import agenda

@Suite("Note images")
struct NoteImageTests {
    /// A solid image encoded as `type`, with an alpha channel when `alpha` is true.
    private func makeImage(width: Int, height: Int, alpha: Bool = false, type: UTType = .png) throws -> Data {
        let info = alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: alpha ? 0.5 : 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func describe(_ data: Data) throws -> (width: Int, height: Int, type: String) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (
            try #require(properties[kCGImagePropertyPixelWidth] as? Int),
            try #require(properties[kCGImagePropertyPixelHeight] as? Int),
            try #require(CGImageSourceGetType(source) as String?)
        )
    }

    @Test func rejectsDataThatIsNotAnImage() {
        #expect(NoteImage.prepared(Data("not an image".utf8)) == nil)
        #expect(NoteImage.prepared(Data()) == nil)
    }

    @Test func keepsSmallImagesUnchanged() throws {
        let png = try makeImage(width: 400, height: 300)

        #expect(NoteImage.prepared(png) == png)
    }

    @Test func shrinksLargeImagesToTheMaximumSide() throws {
        let large = try makeImage(width: 4000, height: 1000)

        let prepared = try #require(NoteImage.prepared(large))
        let size = try describe(prepared)

        #expect(size.width == NoteImage.maxPixelSize)
        #expect(size.height == 512)
    }

    @Test func shrunkOpaqueImagesBecomeJPEGAndTransparentOnesStayPNG() throws {
        let opaque = try #require(NoteImage.prepared(try makeImage(width: 3000, height: 3000)))
        let transparent = try #require(NoteImage.prepared(try makeImage(width: 3000, height: 3000, alpha: true)))

        #expect(try describe(opaque).type == UTType.jpeg.identifier)
        #expect(try describe(transparent).type == UTType.png.identifier)
    }

    @Test func reencodesFormatsOtherMacsMightNotShowAsIs() throws {
        let tiff = try makeImage(width: 200, height: 100, type: .tiff)

        let prepared = try #require(NoteImage.prepared(tiff))
        let size = try describe(prepared)

        #expect(size.type == UTType.jpeg.identifier)
        #expect(size.width == 200)
        #expect(size.height == 100)
    }
}
