import Foundation

protocol AvatarService: AnyObject {
    func uploadAvatar(_ jpegData: Data) async throws -> UploadedImage
}
