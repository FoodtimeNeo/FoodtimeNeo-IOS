import Foundation

protocol CorrectionService: AnyObject {
    func submit(_ proposal: CorrectionProposal) async throws -> CatalogCorrection
    func mine(page: Int, size: Int) async throws -> Page<CatalogCorrection>
    func detail(id: String) async throws -> CatalogCorrection
}
