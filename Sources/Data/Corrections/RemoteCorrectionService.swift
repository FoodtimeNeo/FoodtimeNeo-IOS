import Foundation

final class RemoteCorrectionService: CorrectionService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func submit(_ proposal: CorrectionProposal) async throws -> CatalogCorrection {
        let request = try APIRequest.json(
            .post,
            "users/me/catalog-corrections",
            body: proposal,
            requiresAuth: true,
            requiresCSRF: true
        )
        return try await api.send(request, as: CatalogCorrection.self)
    }

    func mine(page: Int, size: Int) async throws -> Page<CatalogCorrection> {
        try await api.send(
            .get(
                "users/me/catalog-corrections",
                query: [
                    URLQueryItem(name: "page", value: String(max(1, page))),
                    URLQueryItem(name: "size", value: String(min(100, max(1, size))))
                ]
            ),
            as: Page<CatalogCorrection>.self
        )
    }

    func detail(id: String) async throws -> CatalogCorrection {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await api.send(
            .get("users/me/catalog-corrections/\(encoded)"),
            as: CatalogCorrection.self
        )
    }
}
