import Foundation

protocol SocialService: AnyObject {
    func searchUsers(query: String, page: Int, size: Int) async throws -> Page<SocialUser>
    func following(userID: String, page: Int, size: Int) async throws -> Page<SocialUser>
    func followers(userID: String, page: Int, size: Int) async throws -> Page<SocialUser>
    func follow(userID: String) async throws -> FollowState
    func unfollow(userID: String) async throws -> FollowState
    func blockedUsers(page: Int, size: Int) async throws -> Page<BlockedUser>
    func blockState(userID: String) async throws -> BlockState
    func block(userID: String) async throws -> BlockState
    func unblock(userID: String) async throws -> BlockState
}
