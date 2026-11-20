import XCTest
import UIKit
@testable import FoodtimeNeo

final class AvatarCropRendererTests: XCTestCase {
    func testExports512SquareJPEG() throws {
        let image = testImage(width: 400, height: 300)

        let rendered = try XCTUnwrap(
            AvatarCropRenderer.export(
                image: image,
                rotation: 0,
                zoom: 1,
                panX: 0,
                panY: 0,
                viewportWidth: 320,
                viewportHeight: 320
            )
        )
        let data = try XCTUnwrap(
            AvatarCropRenderer.exportJPEG(
                image: image,
                rotation: 0,
                zoom: 1,
                panX: 0,
                panY: 0,
                viewportWidth: 320,
                viewportHeight: 320
            )
        )

        XCTAssertEqual(rendered.size.width, 512)
        XCTAssertEqual(rendered.size.height, 512)
        XCTAssertFalse(data.isEmpty)
        XCTAssertLessThanOrEqual(data.count, 10 * 1024 * 1024)
    }

    func testRotationStillExports() throws {
        let image = testImage(width: 300, height: 500)

        let data = try XCTUnwrap(
            AvatarCropRenderer.exportJPEG(
                image: image,
                rotation: 90,
                zoom: 2,
                panX: 0.2,
                panY: -0.1,
                viewportWidth: 320,
                viewportHeight: 320
            )
        )

        XCTAssertFalse(data.isEmpty)
    }

    func testInvalidViewportFails() {
        XCTAssertNil(
            AvatarCropRenderer.export(
                image: testImage(width: 100, height: 100),
                rotation: 0,
                zoom: 1,
                panX: 0,
                panY: 0,
                viewportWidth: 20,
                viewportHeight: 20
            )
        )
    }

    private func testImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.orange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                UIColor.blue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
            }
    }
}
