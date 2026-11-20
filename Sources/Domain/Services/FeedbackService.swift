import Foundation

protocol FeedbackService: AnyObject {
    func create(type: FeedbackType, content: String, requestID: String) async throws -> Feedback
    func list(archived: Bool, page: Int, size: Int) async throws -> Page<Feedback>
    func detail(id: String) async throws -> Feedback
    func replies(id: String, page: Int, size: Int) async throws -> Page<FeedbackReply>
}
