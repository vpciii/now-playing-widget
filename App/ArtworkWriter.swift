import Foundation
import ImageIO
import NowPlayingCore
import UniformTypeIdentifiers

/// Stores artwork for the widget, downscaled so the widget stays within
/// WidgetKit's image size limits.
enum ArtworkWriter {
    /// Writes `imageData` as a JPEG named `fileName` in the shared folder.
    /// Returns the file name on success, nil if the data is not an image.
    static func write(_ imageData: Data, as fileName: String) -> String? {
        guard let directory = SharedContainer.url(),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: ArtworkFile.maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let url = directory.appendingPathComponent(fileName)
        let temporary = directory.appendingPathComponent(fileName + ".tmp")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            temporary as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        _ = try? FileManager.default.replaceItemAt(url, withItemAt: temporary)
        return FileManager.default.fileExists(atPath: url.path) ? fileName : nil
    }

    static func remove(_ fileName: String) {
        guard let directory = SharedContainer.url() else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
