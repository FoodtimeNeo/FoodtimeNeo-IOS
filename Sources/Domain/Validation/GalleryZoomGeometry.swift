import Foundation

/// 双击缩放的锚点与边界计算；与具体视图无关，便于测试。
enum GalleryZoomGeometry {
    static func anchoredOffset(
        tap: CGPoint,
        container: CGSize,
        scale: CGFloat
    ) -> CGSize {
        guard container.width > 0, container.height > 0, scale > 1 else { return .zero }
        let rawX = -(tap.x - container.width / 2) * (scale - 1)
        let rawY = -(tap.y - container.height / 2) * (scale - 1)
        return clampedOffset(
            CGSize(width: rawX, height: rawY),
            scale: scale,
            container: container
        )
    }

    static func clampedOffset(
        _ offset: CGSize,
        scale: CGFloat,
        container: CGSize
    ) -> CGSize {
        guard scale > 1 else { return .zero }
        let maxX = container.width * (scale - 1) / 2
        let maxY = container.height * (scale - 1) / 2
        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }
}
