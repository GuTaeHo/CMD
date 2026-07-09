import Foundation

/// 앱에서 열어 본 하나의 마크다운 문서.
/// 보안 스코프 문제를 피하기 위해 선택 시점에 내용을 즉시 읽어 캐싱한다.
struct MarkdownFile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let content: String
    let url: URL?
    let openedAt: Date
    let bookmarkData: Data?

    init(id: UUID = UUID(), name: String, content: String, url: URL? = nil, openedAt: Date = Date(), bookmarkData: Data? = nil) {
        self.id = id
        self.name = name
        self.content = content
        self.url = url
        self.openedAt = openedAt
        self.bookmarkData = bookmarkData
    }

    /// 목록에서 보여줄 미리보기 텍스트 (마크다운 기호를 대충 걷어낸 첫 줄)
    var preview: String {
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let stripped = line
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: ">", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !stripped.isEmpty { return stripped }
        }
        return AppLocalization.string("빈 문서", comment: "문서에 표시할 내용이 없을 때의 미리보기")
    }
}
