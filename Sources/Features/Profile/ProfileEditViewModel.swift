import Combine
import Foundation

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var displayName = ""
    @Published private(set) var profile: UserProfile?
    @Published private(set) var avatarUrl: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var didSave = false

    private let session: AppSession
    private var hasLoaded = false

    init(session: AppSession) {
        self.session = session
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let profile = try await session.currentProfile()
            self.profile = profile
            displayName = profile.displayName
            avatarUrl = profile.avatarUrl
            hasLoaded = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setAvatarUrl(_ url: String) {
        avatarUrl = url
    }

    func save() async {
        guard !isSaving else { return }
        if let error = ProfileValidation.displayNameError(displayName) {
            errorMessage = error
            return
        }
        guard let profile else {
            errorMessage = "资料尚未读取，请稍后重试"
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await session.updateProfile(
                displayName: ProfileValidation.normalizedDisplayName(displayName),
                avatarUrl: avatarUrl ?? profile.avatarUrl
            )
            self.profile = updated
            displayName = updated.displayName
            avatarUrl = updated.avatarUrl
            didSave = true
        } catch let error as AppError {
            if case .validation(let fields) = error {
                errorMessage = fields.isEmpty
                    ? error.localizedDescription
                    : fields.map(\.message).joined(separator: "；")
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
