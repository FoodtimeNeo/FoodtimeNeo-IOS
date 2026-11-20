import Foundation

protocol SubmissionService: AnyObject {
    func uploadImage(_ jpegData: Data) async throws -> UploadedImage
    func submitDishImage(dishID: String, imageURL: String) async throws -> ImageSubmission
    func myImageSubmissions(page: Int, size: Int) async throws -> Page<ImageSubmission>
}
