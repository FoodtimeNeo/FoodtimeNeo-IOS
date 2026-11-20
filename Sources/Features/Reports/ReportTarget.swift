import Foundation

struct ReportTarget: Identifiable, Equatable {
    let type: String
    let targetID: String

    var id: String { "\(type):\(targetID)" }
}
