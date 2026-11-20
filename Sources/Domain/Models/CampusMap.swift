import Foundation

struct CampusMapRegion: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let polygon: [[Double]]
    let diningHallIds: [String]
}

struct CampusMapData: Codable, Equatable, Sendable {
    let version: String
    let width: Double
    let height: Double
    let regions: [CampusMapRegion]
}

enum CampusMapGeometry {
    /// Ray casting in image coordinates. No GPS or platform view involved.
    static func contains(polygon: [[Double]], x: Double, y: Double) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[j]
            guard a.count >= 2, b.count >= 2 else { j = i; continue }
            if (a[1] > y) != (b[1] > y),
               x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0] {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    static func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        max(minimum, min(maximum, value))
    }
}
