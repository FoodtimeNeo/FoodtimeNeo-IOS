import Foundation
import ImageIO
import UIKit

enum CampusMapAssets {
    static func loadData(bundle: Bundle = .main) throws -> CampusMapData {
        guard let url = resourceURL(name: "regions", extension: "json", bundle: bundle) else {
            throw CampusMapAssetError.missing("regions.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CampusMapData.self, from: data)
    }

    /// Downsample the 5032×3579 map; full-size decode is about 72 MB.
    static func loadImage(maxPixel: Int = 2600, bundle: Bundle = .main) throws -> UIImage {
        guard let url = resourceURL(name: "campus-map", extension: "webp", bundle: bundle) else {
            throw CampusMapAssetError.missing("campus-map.webp")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CampusMapAssetError.invalidImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CampusMapAssetError.invalidImage
        }
        return UIImage(cgImage: image)
    }

    private static func resourceURL(name: String, extension ext: String, bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: "CampusMap")
            ?? bundle.url(forResource: name, withExtension: ext)
    }
}

enum CampusMapAssetError: Error, LocalizedError {
    case missing(String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .missing(let name): return "缺少地图资源：\(name)"
        case .invalidImage: return "地图图片无法解析"
        }
    }
}
