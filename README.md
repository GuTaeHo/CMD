# CMD

**CMD (Cocoa Mark Down)** 는 iOS와 macOS에서 동작하는 SwiftUI 기반 마크다운
뷰어입니다. 로컬 마크다운 파일을 열어 렌더링해 보여주고, 글자 크기와 화면
모드를 취향에 맞게 조절할 수 있습니다.

## 지원 버전

- iOS 15.0 이상
- macOS 12.0 이상
- iPhone / iPad / Mac 지원
- Swift 5.0, Xcode 15

## 의존성

외부 라이브러리를 사용하지 않습니다. Apple 기본 프레임워크만 사용합니다.

- `SwiftUI` — 화면 구성
- `Foundation` — 파일/데이터 처리
- `UniformTypeIdentifiers` — 파일 선택 시 허용 타입 지정

Swift Package / CocoaPods / Carthage 등 별도 패키지 매니저가 필요 없습니다.

## 앱 구조

모든 소스는 `CMD.xcodeproj` 와 같은 위치(루트)에 있습니다.

```
CMDApp.swift              앱 진입점(@main). AppSettings·DocumentStore 주입
CMD.entitlements          샌드박스 및 사용자 선택 파일 읽기 권한
Assets.xcassets/          앱 아이콘, 강조 색상
Models/
  AppSettings.swift       글자 크기·화면 모드 설정 (UserDefaults 저장)
  DocumentStore.swift     열린 문서 목록 관리, 파일 가져오기
  MarkdownFile.swift      열어 본 문서 1개 (내용은 열 때 캐싱)
  SampleContent.swift     기본 제공 환영 문서
Markdown/
  MarkdownParser.swift    줄 단위 마크다운 파서 → 블록 배열 변환
  MarkdownBlockView.swift 마크다운 블록을 SwiftUI 로 렌더링
Views/
  RootView.swift          최상위 화면 (macOS 는 2단 레이아웃)
  FileListView.swift      문서 목록, 파일 열기, 툴바
  MarkdownViewerView.swift 렌더링된 문서 뷰어
  SettingsView.swift      환경설정 시트 (글자 크기·화면 모드)
```

상태는 `CMDApp` 에서 만든 두 개의 `EnvironmentObject` 로 흐릅니다.
`AppSettings`(설정, UserDefaults 에 저장)와 `DocumentStore`(열린 문서 목록,
메모리 보관)입니다. 마크다운 렌더링은 완전한 CommonMark 구현이 아니라 뷰어에
필요한 핵심 문법(제목·문단·목록·코드 블록·인용·이미지·수평선)만 다루는 가벼운
자체 파서를 사용합니다.

## 사용법

1. Xcode 15 이상에서 `CMD.xcodeproj` 를 엽니다.
2. `CMD` 스킴을 선택하고 실행 대상(Mac 또는 iOS 시뮬레이터/기기)을 고른 뒤
   실행합니다.
3. 앱이 열리면 기본 환영 문서가 목록에 보입니다.
4. 툴바의 **＋(파일 열기)** 버튼으로 `.md` · `.markdown` · `.txt` 파일을 열어
   목록에 추가하고, 목록에서 문서를 선택하면 렌더링된 내용을 볼 수 있습니다.
5. 툴바의 **톱니바퀴(환경설정)** 버튼에서 글자 크기와 화면 모드(라이트/다크/
   시스템)를 조절할 수 있습니다.
