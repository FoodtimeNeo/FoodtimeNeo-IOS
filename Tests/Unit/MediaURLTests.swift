import XCTest
@testable import FoodtimeNeo

final class MediaURLTests: XCTestCase {
    private let base = URL(string: "https://bjtufoodtime.top/api/v1/")!

    func testAbsoluteURLIsKept() {
        XCTAssertEqual(
            MediaURL.resolve("https://cdn.example.com/a.jpg", baseURL: base)?.absoluteString,
            "https://cdn.example.com/a.jpg"
        )
    }

    func testSameOriginReferencesResolve() {
        XCTAssertEqual(
            MediaURL.resolve("/api/v1/media/abc", baseURL: base)?.absoluteString,
            "https://bjtufoodtime.top/api/v1/media/abc"
        )
        XCTAssertEqual(
            MediaURL.resolve("media/abc", baseURL: base)?.absoluteString,
            "https://bjtufoodtime.top/api/v1/media/abc"
        )
        XCTAssertNil(MediaURL.resolve("   ", baseURL: base))
    }
}
