import Foundation

struct AppealDraft: Equatable, Sendable {
    var content: String
    var evidence: [Data]
}

/// 申诉草稿按服务来源与账号隔离保存，供受限会话重新认证后恢复。
protocol AppealDraftStoring: AnyObject {
    func load(decisionID: String) -> AppealDraft?
    func save(_ draft: AppealDraft, decisionID: String)
    func clear(decisionID: String)
}
