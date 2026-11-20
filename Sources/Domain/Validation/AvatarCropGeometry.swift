import Foundation

/// 与 Android `AvatarCropGeometry` 等价的裁剪几何；pan 以方形边长比例表示。
enum AvatarCropGeometry {
    static let maxBytes = 10 * 1024 * 1024
    static let exportSide: CGFloat = 512

    struct Layout: Equatable {
        let side: CGFloat
        let left: CGFloat
        let top: CGFloat
        let scale: CGFloat
        let panX: CGFloat
        let panY: CGFloat
    }

    static func calculate(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        rotation: Int,
        zoom: CGFloat,
        panX: CGFloat,
        panY: CGFloat
    ) -> Layout {
        let side = max(1, min(viewportWidth, viewportHeight) - 32)
        let swapped = rotation % 180 != 0
        let width = swapped ? imageHeight : imageWidth
        let height = swapped ? imageWidth : imageHeight
        let clampedZoom = max(1, min(4, zoom))
        let scale = max(side / max(1, width), side / max(1, height)) * clampedZoom
        let maxX = max(0, (width * scale - side) / 2)
        let maxY = max(0, (height * scale - side) / 2)
        return Layout(
            side: side,
            left: (viewportWidth - side) / 2,
            top: (viewportHeight - side) / 2,
            scale: scale,
            panX: max(-maxX, min(maxX, panX * side)),
            panY: max(-maxY, min(maxY, panY * side))
        )
    }
}
