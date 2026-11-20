import Foundation

protocol SubmissionService: AnyObject {
    func uploadImage(_ jpegData: Data) async throws -> UploadedImage
    func submitDishImage(dishID: String, imageURL: String) async throws -> ImageSubmission
    func myImageSubmissions(page: Int, size: Int) async throws -> Page<ImageSubmission>
    func submitDish(
        stallID: String,
        name: String,
        description: String?,
        price: Decimal?,
        imageURL: String
    ) async throws -> CatalogSubmissionReceipt
    func submitStall(
        hallID: String,
        name: String,
        description: String?,
        coverImageURL: String
    ) async throws -> CatalogSubmissionReceipt
    func myDishSubmissions(page: Int, size: Int) async throws -> Page<DishSubmission>
    func myStallSubmissions(page: Int, size: Int) async throws -> Page<StallSubmission>
}
