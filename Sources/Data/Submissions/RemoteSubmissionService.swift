import Foundation

final class RemoteSubmissionService: SubmissionService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func uploadImage(_ jpegData: Data) async throws -> UploadedImage {
        let boundary = "foodtime-\(UUID().uuidString)"
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        body.appendString("\r\n--\(boundary)--\r\n")

        let request = APIRequest(
            method: .post,
            path: "uploads/images",
            body: body,
            requiresAuth: true,
            requiresCSRF: true,
            timeout: 180,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        return try await api.send(request, as: UploadedImage.self)
    }

    func submitDishImage(dishID: String, imageURL: String) async throws -> ImageSubmission {
        struct Body: Encodable {
            let imageUrl: String
        }
        let request = try APIRequest.json(
            .post,
            "dishes/\(encoded(dishID))/image-submissions",
            body: Body(imageUrl: imageURL),
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: ImageSubmission.self)
    }

    func myImageSubmissions(page: Int, size: Int) async throws -> Page<ImageSubmission> {
        try await api.send(
            .get(
                "users/me/image-submissions",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<ImageSubmission>.self
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

private extension Data {
    mutating func appendString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }
}
