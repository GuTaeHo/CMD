import Foundation

/// 첫 실행 시 보여줄 예제 문서.
enum SampleContent {
    static let welcome = MarkdownFile(
        name: "환영합니다.md",
        content: """
        # 안녕하세요!

        **CMD** (Cocoa Mark Down) 는 macOS, iPhone, iPad 에서 동작하는
        가벼운 마크다운 *뷰어* 입니다.

        ## 주요 기능

        - 파일 선택 화면과 뷰어 화면으로 단순하게 구성
        - 오른쪽 위 **환경설정** 에서 글자 크기 조정
        - 라이트 / 다크 모드 전환

        ## 지원하는 마크다운

        제목, 목록, 인용, 코드 등 기본 문법을 지원합니다.

        1. 순서 있는 목록
        2. 두 번째 항목
        3. 세 번째 항목

        > 인용문은 이렇게 표시됩니다.
        > 여러 줄도 가능합니다.

        ## 이미지

        마크다운 문법과 `<img>` 태그를 모두 지원합니다.

        ![샘플 이미지](https://picsum.photos/600/300)

        <img src="https://picsum.photos/500/280" alt="HTML img 태그 예시">

        인라인 코드 `let x = 42` 와 코드 블록도 지원합니다.

        ```swift
        struct Hello {
            let message = "Hello, CMD!"
        }
        ```

        ---

        직접 `.md` 파일을 열어 확인해 보세요. 🚀
        """
    )
}
