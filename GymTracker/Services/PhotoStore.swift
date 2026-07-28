import Foundation
import UIKit
import ImageIO

/// Stores progress photos as JPEG files in Application Support. Only the
/// file name goes into the database; images are downscaled on import so
/// years of photos stay a manageable size.
enum PhotoStore {
    private static let maxDimension: CGFloat = 1600

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Downscales, re-encodes and writes the picked image; returns the file
    /// name to store on the ProgressPhoto row.
    static func save(_ data: Data) throws -> String {
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let jpeg = downscaled(image).jpegData(compressionQuality: 0.8) ?? data
        let fileName = UUID().uuidString + ".jpg"
        try jpeg.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    static func loadImage(_ fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    private static let thumbnailCache = NSCache<NSString, UIImage>()

    /// Small cached rendition for the strip, downsampled via ImageIO so the
    /// full 1600px bitmap never gets decoded just to draw an 84pt tile.
    static func thumbnail(_ fileName: String, maxPixel: CGFloat = 480) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        if let cached = thumbnailCache.object(forKey: fileName as NSString) {
            return cached
        }
        let url = directory.appendingPathComponent(fileName)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return loadImage(fileName)
        }
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    static func delete(_ fileName: String) {
        guard !fileName.isEmpty else { return }
        thumbnailCache.removeObject(forKey: fileName as NSString)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension, largest > 0 else { return image }
        let scale = maxDimension / largest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
