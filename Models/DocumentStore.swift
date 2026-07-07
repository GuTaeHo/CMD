import Foundation
import SwiftUI

/// 열린 마크다운 문서 목록을 관리한다.
final class DocumentStore: ObservableObject {
    @Published private(set) var files: [MarkdownFile] = []
    @Published var lastError: String?

    init() {
        files = [SampleContent.welcome]
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
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let content = String(decoding: data, as: UTF8.self)
        return MarkdownFile(name: url.lastPathComponent, content: content, url: url)
    }

    private func add(_ file: MarkdownFile) {
        // 같은 경로의 문서는 최신 내용으로 갱신
        if let url = file.url, let index = files.firstIndex(where: { $0.url == url }) {
            files[index] = file
        } else {
            files.insert(file, at: 0)
        }
    }

    func remove(_ file: MarkdownFile) {
        files.removeAll { $0.id == file.id }
    }
}
