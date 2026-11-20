import Foundation

struct AdminFeedbackRow: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String
    let content: String
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
    let userDisplayName: String?
    let latestReply: String?
}

struct AdminFeedbackReply: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let content: String
    let createdAt: Date?
}

struct AdminFeedbackExport: Codable, Equatable, Sendable {
    let filename: String
    let csv: String
    let count: Int
}

struct AdminFeedbackIssue: Codable, Identifiable, Equatable, Sendable {
    let row: Int
    let message: String

    var id: Int { row }
}

struct AdminFeedbackImportResult: Codable, Equatable, Sendable {
    let updated: Int
    let skipped: Int
    let issues: [AdminFeedbackIssue]
}

enum AdminFeedbackStatus: String, CaseIterable, Identifiable {
    case pending
    case processing
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "待处理"
        case .processing: return "处理中"
        case .completed: return "已完成"
        }
    }
}
