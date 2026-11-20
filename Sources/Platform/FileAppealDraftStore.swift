import Foundation

/// 文件系统草稿仓库。目录按服务来源与账号 UUID 隔离，避免切号串用。
final class FileAppealDraftStore: AppealDraftStoring {
    private let directory: URL
    private let fileManager: FileManager

    init(
        origin: URL,
        accountID: String,
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let root = rootDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let scope = Self.scopeName(origin.absoluteString)
        self.directory = root
            .appendingPathComponent("FoodtimeAppealDrafts", isDirectory: true)
            .appendingPathComponent(scope, isDirectory: true)
            .appendingPathComponent(accountID, isDirectory: true)
    }

    func load(decisionID: String) -> AppealDraft? {
        let folder = folder(for: decisionID)
        let contentURL = folder.appendingPathComponent("content.txt")
        guard let data = try? Data(contentsOf: contentURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        var evidence: [Data] = []
        for index in 0..<3 {
            let url = folder.appendingPathComponent("evidence-\(index).jpg")
            if let image = try? Data(contentsOf: url) {
                evidence.append(image)
            }
        }
        if content.isEmpty && evidence.isEmpty {
            return nil
        }
        return AppealDraft(content: content, evidence: evidence)
    }

    func save(_ draft: AppealDraft, decisionID: String) {
        let folder = folder(for: decisionID)
        guard (try? fileManager.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )) != nil else { return }
        try? Data(draft.content.utf8).write(
            to: folder.appendingPathComponent("content.txt"),
            options: .atomic
        )
        for index in 0..<3 {
            let url = folder.appendingPathComponent("evidence-\(index).jpg")
            if index < draft.evidence.count {
                try? draft.evidence[index].write(to: url, options: .atomic)
            } else {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func clear(decisionID: String) {
        try? fileManager.removeItem(at: folder(for: decisionID))
    }

    private func folder(for decisionID: String) -> URL {
        let safe = decisionID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? decisionID
        return directory.appendingPathComponent(safe, isDirectory: true)
    }

    private static func scopeName(_ value: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
