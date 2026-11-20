import XCTest
@testable import FoodtimeNeo

final class CampusMapGeometryTests: XCTestCase {
    private let square: [[Double]] = [[0, 0], [10, 0], [10, 10], [0, 10]]

    func testPointInPolygon() {
        XCTAssertTrue(CampusMapGeometry.contains(polygon: square, x: 5, y: 5))
        XCTAssertFalse(CampusMapGeometry.contains(polygon: square, x: 15, y: 5))
        XCTAssertFalse(CampusMapGeometry.contains(polygon: square, x: 5, y: -1))
        XCTAssertFalse(CampusMapGeometry.contains(polygon: [], x: 0, y: 0))
    }

    func testClamp() {
        XCTAssertEqual(CampusMapGeometry.clamp(2, 1, 6), 2)
        XCTAssertEqual(CampusMapGeometry.clamp(0, 1, 6), 1)
        XCTAssertEqual(CampusMapGeometry.clamp(9, 1, 6), 6)
    }

    func testMapDataDecodes() throws {
        let json = """
        {"version":"v1","width":100,"height":50,"regions":[{"id":"r","name":"区域","polygon":[[0,0],[10,0],[10,10]],"diningHallIds":["h-1"]}]}
        """
        let data = try JSONDecoder().decode(CampusMapData.self, from: Data(json.utf8))
        XCTAssertEqual(data.regions.first?.diningHallIds, ["h-1"])
    }
}
