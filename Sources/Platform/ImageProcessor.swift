import Foundation
import UIKit

enum ImageProcessor {
    /// Bakes orientation, downsamples the longest side and returns JPEG data.
    /// HEIC and other input formats are normalized before upload.
    static func jpegData(from image: UIImage, maxPixel: Int = 1600, quality: CGFloat = 0.9) -> Data? {
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        guard longest > 0 else { return nil }
        let ratio = min(1, CGFloat(maxPixel) / longest)
        let target = CGSize(
            width: max(1, (image.size.width * image.scale * ratio).rounded()),
            height: max(1, (image.size.height * image.scale * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return normalized.jpegData(compressionQuality: quality)
    }

    static func pixelCount(_ image: UIImage) -> Int {
        Int(image.size.width * image.scale) * Int(image.size.height * image.scale)
    }
}
