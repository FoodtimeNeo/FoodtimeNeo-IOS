import Foundation

/// One draft per account, stored as JSON plus JPEG files under Application
/// Support. Atomic writes, excluded from backup; clear only on account deletion.
final class FileCommunityDraftStore: CommunityDraftStore {
    private let baseDirectory: URL
    private let fileManager = FileManager.default

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.baseDirectory = support.appendingPathComponent("community-drafts", isDirectory: true)
        }
    }

    private func directory(for accountID: String) -> URL {
        baseDirectory.appendingPathComponent(safe(accountID), isDirectory: true)
    }

    private func draftURL(for accountID: String) -> URL {
        directory(for: accountID).appendingPathComponent("draft.json")
    }

    private func imagesDirectory(for accountID: String) -> URL {
        directory(for: accountID).appendingPathComponent("images", isDirectory: true)
    }

    func load(accountID: String) -> CommunityDraft? {
        guard let data = try? Data(contentsOf: draftURL(for: accountID)) else { return nil }
        return try? JSONDecoder().decode(CommunityDraft.self, from: data)
    }

    func save(_ draft: CommunityDraft, accountID: String) {
        do {
            let dir = directory(for: accountID)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(draft)
            try data.write(to: draftURL(for: accountID), options: .atomic)
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: draftURL(for: accountID).path
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = draftURL(for: accountID)
            try? mutable.setResourceValues(values)
            pruneImages(keeping: Set(draft.imageFiles), accountID: accountID)
        } catch {
            // A failed autosave must not destroy the in-memory draft.
        }
    }

    func saveImage(_ data: Data, accountID: String) -> String? {
        do {
            let images = imagesDirectory(for: accountID)
            try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
            let name = "\(UUID().uuidString).jpg"
            let url = images.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = url
            try? mutable.setResourceValues(values)
            return name
        } catch {
            return nil
        }
    }

    func imageData(named: String, accountID: String) -> Data? {
        try? Data(contentsOf: imagesDirectory(for: accountID).appendingPathComponent(named))
    }

    func clear(accountID: String) {
        try? fileManager.removeItem(at: directory(for: accountID))
    }

    private func pruneImages(keeping names: Set<String>, accountID: String) {
        let images = imagesDirectory(for: accountID)
        guard let files = try? fileManager.contentsOfDirectory(at: images, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where !names.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private func safe(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
    }
}
