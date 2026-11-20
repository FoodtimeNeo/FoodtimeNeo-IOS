import Foundation

final class RemoteAvatarService: AvatarService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func uploadAvatar(_ jpegData: Data) async throws -> UploadedImage {
        let boundary = "foodtime-avatar-\(UUID().uuidString)"
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        body.appendString("\r\n--\(boundary)--\r\n")

        let request = APIRequest(
            method: .post,
            path: "uploads/avatars",
            body: body,
            requiresAuth: true,
            requiresCSRF: true,
            timeout: 180,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        let uploaded = try await api.send(request, as: UploadedImage.self)
        guard uploaded.imageUrl.hasPrefix("/api/v1/media/") else {
            throw AppError.invalidResponse(message: "头像上传响应异常，请重试")
        }
        return uploaded
    }
}

private extension Data {
    mutating func appendString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }
}
