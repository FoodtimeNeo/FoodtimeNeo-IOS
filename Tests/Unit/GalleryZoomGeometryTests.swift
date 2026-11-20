import XCTest
@testable import FoodtimeNeo

final class GalleryZoomGeometryTests: XCTestCase {
    func testCenterTapKeepsImageCentered() {
        let offset = GalleryZoomGeometry.anchoredOffset(
            tap: CGPoint(x: 160, y: 240),
            container: CGSize(width: 320, height: 480),
            scale: 2.5
        )

        XCTAssertEqual(offset.width, 0, accuracy: 0.001)
        XCTAssertEqual(offset.height, 0, accuracy: 0.001)
    }

    func testRightEdgeTapMovesImageLeft() {
        let offset = GalleryZoomGeometry.anchoredOffset(
            tap: CGPoint(x: 320, y: 240),
            container: CGSize(width: 320, height: 480),
            scale: 2.5
        )

        XCTAssertLessThan(offset.width, 0)
    }

    func testOffsetIsClampedToScaledBounds() {
        let clamped = GalleryZoomGeometry.clampedOffset(
            CGSize(width: 5_000, height: -5_000),
            scale: 3,
            container: CGSize(width: 300, height: 400)
        )

        XCTAssertEqual(clamped.width, 300)
        XCTAssertEqual(clamped.height, -400)
    }

    func testNoZoomHasNoOffset() {
        XCTAssertEqual(
            GalleryZoomGeometry.clampedOffset(
                CGSize(width: 100, height: 100),
                scale: 1,
                container: CGSize(width: 300, height: 300)
            ),
            .zero
        )
        XCTAssertEqual(
            GalleryZoomGeometry.anchoredOffset(
                tap: CGPoint(x: 0, y: 0),
                container: CGSize(width: 300, height: 300),
                scale: 1
            ),
            .zero
        )
    }
}
