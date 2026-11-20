import UIKit

/// 把同一套几何应用到原图，导出 512×512 JPEG；预览与导出使用完全相同的变换。
enum AvatarCropRenderer {
    static func export(
        image: UIImage,
        rotation: Int,
        zoom: CGFloat,
        panX: CGFloat,
        panY: CGFloat,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> UIImage? {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        guard width >= 1, height >= 1, viewportWidth > 32, viewportHeight > 32 else {
            return nil
        }
        let layout = AvatarCropGeometry.calculate(
            imageWidth: width,
            imageHeight: height,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            rotation: rotation,
            zoom: zoom,
            panX: panX,
            panY: panY
        )
        guard layout.side > 0, layout.scale > 0 else { return nil }

        let outputSide = AvatarCropGeometry.exportSide
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format
        )
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
            let cg = context.cgContext
            let ratio = outputSide / layout.side
            cg.scaleBy(x: ratio, y: ratio)
            cg.translateBy(x: -layout.left, y: -layout.top)
            cg.translateBy(
                x: viewportWidth / 2 + layout.panX,
                y: viewportHeight / 2 + layout.panY
            )
            cg.rotate(by: CGFloat(rotation) * .pi / 180)
            cg.scaleBy(x: layout.scale, y: layout.scale)
            image.draw(
                in: CGRect(
                    x: -width / 2,
                    y: -height / 2,
                    width: width,
                    height: height
                )
            )
        }
        return rendered
    }

    static func exportJPEG(
        image: UIImage,
        rotation: Int,
        zoom: CGFloat,
        panX: CGFloat,
        panY: CGFloat,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat,
        quality: CGFloat = 0.9
    ) -> Data? {
        guard let rendered = export(
            image: image,
            rotation: rotation,
            zoom: zoom,
            panX: panX,
            panY: panY,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight
        ) else {
            return nil
        }
        let data = rendered.jpegData(compressionQuality: quality)
        guard let data, data.count <= AvatarCropGeometry.maxBytes else { return nil }
        return data
    }
}
