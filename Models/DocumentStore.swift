import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 열린 마크다운 문서 목록을 관리한다.
final class DocumentStore: ObservableObject {
    @Published private(set) var files: [MarkdownFile] = []
    @Published var lastError: String?
    /// 목록에서 현재 선택(표시)된 문서 ID. 파일을 가져오면 바로 열리도록 여기에 설정한다.
    @Published var selectedFileID: UUID?

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

    /// fileImporter 로 선택된 URL 들을 읽어 목록에 추가하고, 첫 문서를 바로 연다.
    func `import`(urls: [URL]) {
        var firstImported: MarkdownFile?
        for url in urls {
            do {
                let file = try readFile(at: url)
                add(file)
                if firstImported == nil { firstImported = file }
            } catch {
                lastError = AppLocalization.string(
                    "document.open.error",
                    arguments: [url.lastPathComponent, error.localizedDescription],
                    comment: "파일 열기 실패 오류"
                )
            }
        }
        if let file = firstImported {
            // 목록에 행이 먼저 반영된 뒤 선택해야 NavigationLink 가 확실히 활성화된다.
            DispatchQueue.main.async { [weak self] in
                self?.selectedFileID = file.id
            }
        }
    }

    /// 열 수 있는 문서 타입 목록. fileImporter 와 드래그 & 드롭에서 함께 사용한다.
    static let supportedTypes: [UTType] = {
        var types: [UTType] = [.plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        return types
    }()

    /// 드래그 & 드롭으로 전달된 항목들을 읽어 목록에 추가한다.
    /// - Returns: 처리할 수 있는 항목이 하나라도 있으면 true
    @discardableResult
    func importDropped(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            // macOS 파인더처럼 파일 URL 자체가 전달되는 경우
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    guard let url = Self.fileURL(from: item), Self.isSupportedFile(url) else { return }
                    DispatchQueue.main.async { self?.import(urls: [url]) }
                }
                continue
            }

            // iOS 파일 앱처럼 파일 내용 표현만 전달되는 경우
            guard let typeIdentifier = provider.registeredTypeIdentifiers
                .first(where: Self.isSupportedTypeIdentifier) else { continue }

            accepted = true
            let suggestedName = provider.suggestedName
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, isInPlace, _ in
                guard let self = self, let url = url else { return }
                if isInPlace {
                    DispatchQueue.main.async { self.import(urls: [url]) }
                } else {
                    // 임시 복사본은 이 핸들러가 끝나면 삭제되므로 이 자리에서 바로 읽는다.
                    guard let data = try? Data(contentsOf: url) else { return }
                    let content = String(decoding: data, as: UTF8.self)
                    let name = suggestedName ?? url.lastPathComponent
                    DispatchQueue.main.async {
                        let file = MarkdownFile(name: name, content: content)
                        self.add(file)
                        self.selectedFileID = file.id
                    }
                }
            }
        }
        return accepted
    }

    private static func isSupportedTypeIdentifier(_ identifier: String) -> Bool {
        guard let type = UTType(identifier) else { return false }
        return supportedTypes.contains { type.conforms(to: $0) }
    }

    private static func isSupportedFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return supportedTypes.contains { type.conforms(to: $0) }
    }

    /// 드롭 아이템은 플랫폼에 따라 URL 또는 URL 데이터로 전달된다.
    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }

    /// 앱 안에서 새로 작성한 문서를 목록에 추가한다.
    /// 원본 파일이 없으므로 내용은 UserDefaults 에 저장된 목록으로만 유지된다.
    func createDocument(name: String, content: String) {
        var fileName = name.trimmingCharacters(in: .whitespaces)
        if fileName.isEmpty {
            fileName = AppLocalization.string("새 문서", comment: "새 문서 기본 이름")
        }
        let lowercased = fileName.lowercased()
        if !lowercased.hasSuffix(".md"), !lowercased.hasSuffix(".markdown"), !lowercased.hasSuffix(".txt") {
            fileName += ".md"
        }
        add(MarkdownFile(name: fileName, content: content))
    }

    /// 문서 내용을 수정해 저장한다.
    /// 원본 파일이 있으면 파일에도 직접 쓰고, 실패하면 앱 내 캐시(UserDefaults)로만 보관한다.
    func updateContent(of file: MarkdownFile, to content: String) {
        guard let index = files.firstIndex(where: { $0.id == file.id }) else { return }

        if let url = file.url {
            do {
                try writeContent(content, to: url)
            } catch {
                lastError = AppLocalization.string(
                    "document.write.error",
                    arguments: [file.name, error.localizedDescription],
                    comment: "원본 파일 저장 실패 오류"
                )
            }
        }

        files[index] = MarkdownFile(
            id: file.id,
            name: file.name,
            content: content,
            url: file.url,
            openedAt: file.openedAt,
            bookmarkData: file.bookmarkData
        )
        saveFiles()
    }

    private func writeContent(_ content: String, to url: URL) throws {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        // iCloud 등 파일 프로바이더와 접근을 조율해 동기화 충돌을 피한다.
        var coordinationError: NSError?
        var writeResult: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url,
                                       options: .forReplacing,
                                       error: &coordinationError) { coordinatedURL in
            writeResult = Result { try Data(content.utf8).write(to: coordinatedURL, options: .atomic) }
        }
        if let error = coordinationError { throw error }
        try writeResult.get()
    }

    /// NSFileCoordinator 로 조율된 읽기.
    /// 아직 다운로드되지 않은 iCloud 문서는 코디네이터가 내려받은 뒤 읽는다.
    private func coordinatedRead(at url: URL) throws -> Data {
        var coordinationError: NSError?
        var readResult: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url,
                                       options: [],
                                       error: &coordinationError) { coordinatedURL in
            readResult = Result { try Data(contentsOf: coordinatedURL) }
        }
        if let error = coordinationError { throw error }
        return try readResult.get()
    }

    private func readFile(at url: URL) throws -> MarkdownFile {
        try readFile(at: url, id: UUID(), openedAt: Date())
    }

    private func readFile(at url: URL, id: UUID, openedAt: Date) throws -> MarkdownFile {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try coordinatedRead(at: url)
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
        if selectedFileID == file.id { selectedFileID = nil }
        saveFiles()
    }

    private func loadSavedFiles() -> [MarkdownFile]? {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return nil }

        do {
            return try JSONDecoder()
                .decode([SavedFile].self, from: data)
                .map(restoreFile)
        } catch {
            lastError = AppLocalization.string(
                "document.load_saved.error",
                arguments: [error.localizedDescription],
                comment: "저장된 파일 목록 복원 실패 오류"
            )
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
            lastError = AppLocalization.string(
                "document.save.error",
                arguments: [error.localizedDescription],
                comment: "파일 목록 저장 실패 오류"
            )
        }
    }

    private func makeBookmarkData(for url: URL) -> Data? {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
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
