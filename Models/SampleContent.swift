import Foundation

/// 첫 실행 시 보여줄 예제 문서.
enum SampleContent {
    static let welcome = MarkdownFile(
        name: AppLocalization.string("sample.welcome.name", comment: "첫 실행 샘플 문서 파일명"),
        content: localizedWelcomeContent
    )

    /// 현재 앱 언어에 맞는 번들 샘플 문서를 읽는다.
    private static var localizedWelcomeContent: String {
        guard let url = AppLocalization.url(forResource: "Welcome", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "# CMD\n\nCMD Markdown Viewer"
        }
        return content
    }
}
