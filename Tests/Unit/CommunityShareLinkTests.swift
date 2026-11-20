import XCTest
@testable import FoodtimeNeo

final class CommunityShareLinkTests: XCTestCase {
    func testPostURLMatchesWebRoute() {
        let id = "0f8fad5b-d9cb-469f-a165-70867728950e"
        XCTAssertEqual(
            CommunityShareLink.postURLString(id: id),
            "https://bjtufoodtime.top/community/posts/\(id)"
        )
        XCTAssertEqual(
            CommunityShareLink.postURL(id: id)?.host,
            "bjtufoodtime.top"
        )
        XCTAssertEqual(
            CommunityShareLink.postURL(id: id)?.path,
            "/community/posts/\(id)"
        )
    }

    func testPostURLEncodesUnexpectedCharacters() {
        let value = CommunityShareLink.postURLString(id: "a b/c")
        XCTAssertFalse(value.contains(" "))
        XCTAssertTrue(value.hasPrefix("https://bjtufoodtime.top/community/posts/"))
    }
}
