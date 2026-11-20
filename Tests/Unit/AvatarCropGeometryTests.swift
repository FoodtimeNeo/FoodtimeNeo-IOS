import XCTest
@testable import FoodtimeNeo

final class AvatarCropGeometryTests: XCTestCase {
    func testClampsPanToImageEdges() {
        let layout = AvatarCropGeometry.calculate(
            imageWidth: 100,
            imageHeight: 200,
            viewportWidth: 300,
            viewportHeight: 320,
            rotation: 0,
            zoom: 1,
            panX: 0,
            panY: 2
        )

        XCTAssertEqual(layout.side, 268)
        XCTAssertEqual(layout.scale, 2.68, accuracy: 0.001)
        XCTAssertEqual(layout.panX, 0)
        XCTAssertEqual(layout.panY, 134, accuracy: 0.001)
    }

    func testRotationSwapsAxes() {
        let portrait = AvatarCropGeometry.calculate(
            imageWidth: 100,
            imageHeight: 200,
            viewportWidth: 300,
            viewportHeight: 320,
            rotation: 0,
            zoom: 1,
            panX: 0,
            panY: 0
        )
        let rotated = AvatarCropGeometry.calculate(
            imageWidth: 100,
            imageHeight: 200,
            viewportWidth: 300,
            viewportHeight: 320,
            rotation: 90,
            zoom: 1,
            panX: 0,
            panY: 0
        )

        XCTAssertEqual(portrait.scale, 2.68, accuracy: 0.001)
        XCTAssertEqual(rotated.scale, 2.68, accuracy: 0.001)
        XCTAssertEqual(rotated.side, 268)
    }

    func testZoomIsClamped() {
        let low = AvatarCropGeometry.calculate(
            imageWidth: 100,
            imageHeight: 100,
            viewportWidth: 300,
            viewportHeight: 300,
            rotation: 0,
            zoom: 0.1,
            panX: 0,
            panY: 0
        )
        let high = AvatarCropGeometry.calculate(
            imageWidth: 100,
            imageHeight: 100,
            viewportWidth: 300,
            viewportHeight: 300,
            rotation: 0,
            zoom: 9,
            panX: 0,
            panY: 0
        )

        XCTAssertEqual(low.scale, 2.68, accuracy: 0.001)
        XCTAssertEqual(high.scale, 2.68 * 4, accuracy: 0.001)
    }
}
