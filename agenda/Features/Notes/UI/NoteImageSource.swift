import AppKit
import UniformTypeIdentifiers

/// Reads pictures from the places a person can add them to a note from.
enum NoteImageSource {
    /// Pasteboard pictures, or `nil` when ⌘V should paste text as usual.
    /// Copied image files come first, because Finder also puts their names on the pasteboard as text.
    static func images(on pasteboard: NSPasteboard) -> [Data]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            let files = urls.compactMap { try? Data(contentsOf: $0) }
            return files.isEmpty ? nil : files
        }
        guard pasteboard.string(forType: .string) == nil else { return nil }
        let types: [NSPasteboard.PasteboardType] = [.png, .tiff, NSPasteboard.PasteboardType(UTType.jpeg.identifier), NSPasteboard.PasteboardType(UTType.heic.identifier)]
        guard let type = pasteboard.availableType(from: types), let data = pasteboard.data(forType: type) else { return nil }
        return [data]
    }

    /// The drop types a note accepts: pictures and image files.
    static let dropTypes: [UTType] = [.image, .fileURL]

    /// Loads dropped pictures in order, skipping items that aren't images.
    static func images(from providers: [NSItemProvider]) async -> [Data] {
        var result: [Data] = []
        for provider in providers {
            if let data = await load(provider) {
                result.append(data)
            }
        }
        return result
    }

    /// Loads files picked in the open panel, which are only readable while their access is held.
    static func images(at urls: [URL]) -> [Data] {
        urls.compactMap { url in
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            return try? Data(contentsOf: url)
        }
    }

    private static func load(_ provider: NSItemProvider) async -> Data? {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await withCheckedContinuation { continuation in
                _ = provider.loadDataRepresentation(for: .image) { data, _ in continuation.resume(returning: data) }
            }
        }
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return nil }
        let url: URL? = await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
        }
        return url.flatMap(imageFileData)
    }

    /// Reads a dropped file only when it is an image, so dropping a large video doesn't load it.
    private static func imageFileData(_ url: URL) -> Data? {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
              type.conforms(to: .image) else { return nil }
        return try? Data(contentsOf: url)
    }
}
