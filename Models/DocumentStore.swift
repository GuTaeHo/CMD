import Foundation
import SwiftUI

/// 열린 마크다운 문서 목록을 관리한다.
final class DocumentStore: ObservableObject {
    @Published private(set) var files: [MarkdownFile] = []
    @Published var lastError: String?

    private static let storageKey = "DocumentStore.files.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let savedFiles = loadSavedFiles() {
            files = savedFiles
            saveFiles()
        } else {
            files = [SampleContent.welcome]
        }
    }

    /// fileImporter 로 선택된 URL 들을 읽어 목록에 추가한다.
    func `import`(urls: [URL]) {
        for url in urls {
            do {
                let file = try readFile(at: url)
                add(file)
            } catch {
                lastError = "\"\(url.lastPathComponent)\" 파일을 열 수 없습니다: \(error.localizedDescription)"
            }
        }
    }

    private func readFile(at url: URL) throws -> MarkdownFile {
        try readFile(at: url, id: UUID(), openedAt: Date())
    }

    private func readFile(at url: URL, id: UUID, openedAt: Date) throws -> MarkdownFile {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let content = String(decoding: data, as: UTF8.self)
        return MarkdownFile(
            id: id,
            name: url.lastPathComponent,
            content: content,
            url: url,
            openedAt: openedAt,
            bookmarkData: makeBookmarkData(for: url)
        )
    }

    private func add(_ file: MarkdownFile) {
        // 같은 경로의 문서는 최신 내용으로 갱신
        if let url = file.url, let index = files.firstIndex(where: { $0.url == url }) {
            files[index] = file
        } else {
            files.insert(file, at: 0)
        }
        saveFiles()
    }

    func remove(_ file: MarkdownFile) {
        files.removeAll { $0.id == file.id }
        saveFiles()
    }

    private func loadSavedFiles() -> [MarkdownFile]? {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return nil }

        do {
            return try JSONDecoder()
                .decode([SavedFile].self, from: data)
                .map(restoreFile)
        } catch {
            lastError = "저장된 파일 목록을 불러올 수 없습니다: \(error.localizedDescription)"
            return nil
        }
    }

    private func restoreFile(_ savedFile: SavedFile) -> MarkdownFile {
        var resolvedURL = savedFile.url

        if let bookmarkData = savedFile.bookmarkData {
            if let url = resolveBookmarkData(bookmarkData) {
                resolvedURL = url

                if let refreshedFile = try? readFile(at: url, id: savedFile.id, openedAt: savedFile.openedAt) {
                    return refreshedFile
                }
            }
        } else if let url = savedFile.url,
                  let refreshedFile = try? readFile(at: url, id: savedFile.id, openedAt: savedFile.openedAt) {
            return refreshedFile
        }

        // 원본 파일을 다시 읽지 못해도 마지막으로 열었던 내용을 보여준다.
        return MarkdownFile(
            id: savedFile.id,
            name: savedFile.name,
            content: savedFile.content,
            url: resolvedURL,
            openedAt: savedFile.openedAt,
            bookmarkData: savedFile.bookmarkData
        )
    }

    private func saveFiles() {
        do {
            let savedFiles = files.map(SavedFile.init)
            let data = try JSONEncoder().encode(savedFiles)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            lastError = "파일 목록을 저장할 수 없습니다: \(error.localizedDescription)"
        }
    }

    private func makeBookmarkData(for url: URL) -> Data? {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif

        return try? url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func resolveBookmarkData(_ data: Data) -> URL? {
        var isStale = false

        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif

        return try? URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}

private struct SavedFile: Codable {
    let id: UUID
    let name: String
    let content: String
    let url: URL?
    let openedAt: Date
    let bookmarkData: Data?

    init(file: MarkdownFile) {
        id = file.id
        name = file.name
        content = file.content
        url = file.url
        openedAt = file.openedAt
        bookmarkData = file.bookmarkData
    }
}
