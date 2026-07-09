import SwiftUI

/// 선택된 마크다운 문서를 렌더링해 보여주는 뷰어 화면.
struct MarkdownViewerView: View {
    let file: MarkdownFile
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: DocumentStore

    /// 활성화 시 마크다운 원본(raw)을 그대로 보여준다. 기본값은 렌더링 뷰(비활성화).
    @State private var showRawMarkdown = false

    /// 설정 시트 표시 여부.
    @State private var isSettingsPresented = false

    /// 편집 모드 여부.
    @State private var isEditing = false

    /// 편집 중인 본문.
    @State private var editedContent = ""

    /// 편집으로 저장된 최신 내용. nil 이면 원본(`file.content`)을 사용한다.
    /// `file` 은 목록에서 전달받은 스냅샷이라 저장 후에도 바뀌지 않기 때문에 따로 보관한다.
    @State private var savedContent: String?

    /// 화면에 표시할 현재 문서 내용.
    private var currentContent: String { savedContent ?? file.content }

    /// 파싱된 블록 캐시. 문서 내용이 바뀔 때만 다시 파싱하고,
    /// 글자 크기·행간·자간 같은 설정 변경 시에는 재파싱하지 않는다.
    /// (재파싱하면 블록마다 새 id 가 부여돼 뷰가 재생성되고, 이미지가 다시 로드된다.)
    @State private var blocks: [MarkdownBlock] = []

    /// 긴 원본 텍스트를 한 번에 레이아웃하지 않도록 청크 단위로 나눠 보관한다.
    @State private var rawChunks: [RawMarkdownChunk] = []

    /// 문서 준비 중 표시 여부.
    @State private var isPreparingDocument = false

    /// 문서 전체 줄 수. 문서 준비 시 한 번 계산한다.
    @State private var lineCount = 0

    var body: some View {
        toolbarAttachedBody
            .sheet(isPresented: $isSettingsPresented) {
                settingsSheet
            }
    }

    /// 공통 모디파이어까지 적용된 본문. 툴바는 플랫폼/OS 버전에 따라 따로 붙인다.
    private var viewerCore: some View {
        content
            .task(id: file.id) {
                await prepareDocument()
            }
            .navigationTitle(file.name)
            #if os(iOS)
            // 인라인 타이틀은 뒤로가기 + 우측 버튼 3개에 끼어 몇 자 못 보인다.
            // 라지 타이틀은 자체 줄에 전체 폭으로 표시되고 스크롤하면 자동으로 접힌다.
            // 편집 모드에서는 입력 공간을 위해 인라인으로 되돌린다.
            .navigationBarTitleDisplayMode(isEditing ? .inline : .large)
            #endif
    }

    /// ToolbarContentBuilder 는 iOS 15 에서 빌더 내부 버전 분기(if)를 지원하지
    /// 않으므로, 툴바를 붙이는 지점에서 OS 버전에 따라 통째로 갈아 끼운다.
    @ViewBuilder
    private var toolbarAttachedBody: some View {
        #if os(macOS)
        viewerCore.toolbar { macToolbar }
        #else
        if #available(iOS 16.0, *) {
            viewerCore.toolbar { modernToolbar }
        } else {
            viewerCore.toolbar { legacyToolbar }
        }
        #endif
    }

    #if os(macOS)
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        SidebarToggleToolbarItem()
        // macOS 는 ToolbarItem 내부 뷰를 if/else 로 통째로 교체하면
        // NSToolbar 가 항목을 다시 그리지 않아 버튼이 하얗게 비어 보인다
        // (창 크기를 바꾸면 복구되는 그리기 버그). 두 상태의 컨트롤을
        // 겹쳐 두고 투명도로만 전환해 항목의 뷰 정체성을 유지한다.
        ToolbarItem(placement: .primaryAction) {
            editingSwappedSlot {
                rawMarkdownToggle
            } editing: {
                cancelButton
            }
        }
        ToolbarItem(placement: .primaryAction) {
            editingSwappedSlot {
                editButton
            } editing: {
                saveButton
            }
        }
        // 설정 버튼은 편집 중에도 그대로 둔다. 숨기면(투명도 0) 빈 자리가
        // 우측에 남고, 항목을 제거하면 위의 다시 그리기 버그를 다시 밟는다.
        ToolbarItem(placement: .primaryAction) {
            settingsButton
        }
    }
    #else
    /// iOS 16 이상: placement 별 개별 ToolbarItem 로 배치한다.
    /// 편집 모드 분기는 각 ToolbarItem 내부(ViewBuilder)에서 처리한다.
    @ToolbarContentBuilder
    private var modernToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isEditing {
                cancelButton
            } else {
                rawMarkdownToggle
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if isEditing {
                saveButton
            } else {
                editButton
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if !isEditing {
                settingsButton
            }
        }
    }

    /// iOS 15: 같은 placement 의 ToolbarItem 여러 개도,
    /// ToolbarItemGroup 안의 if/else 분기도 개별 항목으로 분해하지 못해
    /// 첫 항목만 보인다. ToolbarItem 하나에 HStack 으로 직접 배치한다.
    @ToolbarContentBuilder
    private var legacyToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
                if isEditing {
                    cancelButton
                    saveButton
                } else {
                    rawMarkdownToggle
                    editButton
                    settingsButton
                }
            }
        }
    }
    #endif

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        // 편집 모드 진입/종료 때 뷰 계층을 통째로 교체하면 NSToolbar 가
        // 툴바 버튼을 다시 그리지 않아 하얗게 비어 보인다 (창 크기를 바꾸면
        // 복구되는 그리기 버그). 뷰어와 에디터를 겹쳐 두고 투명도로만 전환해
        // 계층 구조를 유지한다.
        ZStack {
            viewerContent
                .opacity(isEditing ? 0 : 1)
                .allowsHitTesting(!isEditing)
            editorView
                .opacity(isEditing ? 1 : 0)
                .allowsHitTesting(isEditing)
                .disabled(!isEditing)
        }
        #else
        if isEditing {
            editorView
        } else {
            viewerContent
        }
        #endif
    }

    /// 렌더링/원본 보기 스크롤 화면.
    private var viewerContent: some View {
        ScrollView {
            if showRawMarkdown {
                RawMarkdownSourceView(chunks: rawChunks,
                                      fontSize: settings.fontSize,
                                      isBoldTextEnabled: settings.resolvedIsBoldTextEnabled,
                                      showLineNumbers: settings.showLineNumbers,
                                      totalLineCount: lineCount,
                                      typographyID: settings.viewerTypographyID)
            } else {
                renderedMarkdownContent
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if settings.showLineCount && lineCount > 0 {
                lineCountBadge
            }
        }
    }

    /// 마크다운 원본 보기 토글.
    private var rawMarkdownToggle: some View {
        Toggle(isOn: $showRawMarkdown) {
            Label("마크다운 원본", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .toggleStyle(.button)
        .help("마크다운 원본 보기")
    }

    /// 편집 모드를 종료하는 취소 버튼.
    private var cancelButton: some View {
        #if os(macOS)
        // 다른 툴바 버튼과 크기를 맞추기 위해 macOS 는 아이콘으로 표시한다.
        Button {
            isEditing = false
        } label: {
            Label("취소", systemImage: "xmark")
        }
        .help("취소")
        #else
        Button("취소") {
            isEditing = false
        }
        #endif
    }

    /// 편집 모드로 진입하는 버튼.
    private var editButton: some View {
        Button {
            editedContent = currentContent
            isEditing = true
        } label: {
            Label("편집", systemImage: "pencil")
        }
        .help("문서 편집")
    }

    /// 편집 내용을 저장하는 버튼.
    private var saveButton: some View {
        Button {
            saveEdits()
        } label: {
            Label("저장", systemImage: "checkmark")
        }
        .help("저장")
    }

    /// 설정 시트를 여는 버튼.
    private var settingsButton: some View {
        Button {
            isSettingsPresented = true
        } label: {
            Label("환경설정", systemImage: "gearshape")
        }
        .help("환경설정")
    }

    #if os(macOS)
    /// 편집 모드에 따라 두 컨트롤 중 하나를 보여주는 툴바 슬롯.
    /// 뷰를 교체하는 대신 겹쳐 두고 투명도로 전환한다 — 교체하면 NSToolbar 가
    /// 항목을 다시 그리지 않아 버튼이 하얗게 비어 보이는 버그가 있다.
    private func editingSwappedSlot<Viewer: View, Editing: View>(
        @ViewBuilder viewer: () -> Viewer,
        @ViewBuilder editing: () -> Editing
    ) -> some View {
        ZStack {
            viewer()
                .opacity(isEditing ? 0 : 1)
                .disabled(isEditing)
            editing()
                .opacity(isEditing ? 1 : 0)
                .disabled(!isEditing)
        }
    }
    #endif

    /// 편집 모드에서 문서 본문을 수정하는 에디터.
    private var editorView: some View {
        TextEditor(text: $editedContent)
            .font(.system(size: settings.fontSize, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #if os(iOS)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            #endif
    }

    /// 편집한 내용을 저장하고 뷰어로 되돌아간다.
    private func saveEdits() {
        savedContent = editedContent
        store.updateContent(of: file, to: editedContent)
        isEditing = false
        Task { await prepareDocument() }
    }

    /// bottom sheet 형태로 표시하는 설정 화면.
    /// presentationDetents 는 iOS 16 / macOS 13 이상에서만 지원하므로 가용성으로 감싼다.
    @ViewBuilder
    private var settingsSheet: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            SettingsView()
        }
    }

    @ViewBuilder
    private var renderedMarkdownContent: some View {
        if isPreparingDocument && blocks.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block,
                                      baseFontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily,
                                      sandollFontWeight: settings.sandollFontWeight,
                                      isBoldTextEnabled: settings.resolvedIsBoldTextEnabled,
                                      lineSpacing: settings.lineSpacing,
                                      letterSpacing: settings.letterSpacing,
                                      typographyID: settings.viewerTypographyID)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    /// 문서 전체 줄 수를 보여주는 배지. 렌더링/원본 보기 모두에서 표시한다.
    private var lineCountBadge: some View {
        Text(AppLocalization.string("viewer.line_count",
                                    arguments: [lineCount],
                                    comment: "뷰어 하단의 문서 전체 줄 수 표기"))
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(12)
            .allowsHitTesting(false)
    }

    private func prepareDocument() async {
        let content = currentContent
        isPreparingDocument = true

        async let parsedBlocks = Task.detached(priority: .userInitiated) {
            MarkdownParser.parse(content)
        }.value

        async let sourceChunks = Task.detached(priority: .utility) {
            RawMarkdownChunk.makeChunks(from: content)
        }.value

        async let countedLines = Task.detached(priority: .utility) {
            Self.countLines(of: content)
        }.value

        let prepared = await (parsedBlocks, sourceChunks, countedLines)
        guard !Task.isCancelled else { return }

        blocks = prepared.0
        rawChunks = prepared.1
        lineCount = prepared.2
        isPreparingDocument = false
    }

    /// 문서의 전체 줄 수를 센다. `\r\n` 은 한 줄로 취급한다.
    private nonisolated static func countLines(of content: String) -> Int {
        guard !content.isEmpty else { return 0 }
        var count = 1
        for character in content where character == "\n" {
            count += 1
        }
        return count
    }
}

/// 원본보기에서 SwiftUI 가 거대한 Text 하나를 계산하지 않도록 나눈 텍스트 조각.
private struct RawMarkdownChunk: Identifiable, Sendable {
    let id: Int
    let text: String
    /// 이 조각의 첫 줄이 문서에서 몇 번째 줄인지 (1부터 시작).
    let startLine: Int

    /// 줄 번호 표시 모드에서 사용할 개별 줄 목록.
    var lines: [String] {
        text.components(separatedBy: "\n")
    }

    static func makeChunks(from content: String, linesPerChunk: Int = 80) -> [RawMarkdownChunk] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        guard !lines.isEmpty else {
            return [RawMarkdownChunk(id: 0, text: " ", startLine: 1)]
        }

        var chunks: [RawMarkdownChunk] = []
        chunks.reserveCapacity((lines.count / linesPerChunk) + 1)

        var index = 0
        while index < lines.count {
            let upperBound = min(index + linesPerChunk, lines.count)
            let chunkText = lines[index..<upperBound].joined(separator: "\n")
            chunks.append(RawMarkdownChunk(id: chunks.count,
                                           text: chunkText.isEmpty ? " " : chunkText,
                                           startLine: index + 1))
            index = upperBound
        }

        return chunks
    }
}

/// 긴 원본 마크다운을 필요한 범위부터 점진적으로 렌더링한다.
private struct RawMarkdownSourceView: View {
    let chunks: [RawMarkdownChunk]
    let fontSize: Double
    let isBoldTextEnabled: Bool
    let showLineNumbers: Bool
    let totalLineCount: Int
    let typographyID: String

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(chunks) { chunk in
                if showLineNumbers {
                    numberedChunk(chunk)
                } else {
                    Text(verbatim: chunk.text)
                        .font(sourceFont)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .id("\(typographyID)|\(showLineNumbers)")
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    /// 각 줄 왼쪽에 줄 번호 거터를 붙여 렌더링한다.
    /// 긴 줄이 접혀도 번호는 첫 줄 기준선에 맞춰 정렬된다.
    private func numberedChunk(_ chunk: RawMarkdownChunk) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chunk.lines.enumerated()), id: \.offset) { offset, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: String(chunk.startLine + offset))
                        .font(lineNumberFont)
                        .foregroundColor(.secondary)
                        .frame(width: gutterWidth, alignment: .trailing)
                    Text(verbatim: line.isEmpty ? " " : line)
                        .font(sourceFont)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// 줄 번호 열의 폭. 문서 전체 자릿수에 맞춰 한 번에 계산해 줄마다 흔들리지 않게 한다.
    private var gutterWidth: CGFloat {
        let digits = max(2, String(max(totalLineCount, 1)).count)
        return CGFloat(digits) * CGFloat(fontSize) * 0.62 + 4
    }

    private var sourceFont: Font {
        if isBoldTextEnabled {
            return .system(size: fontSize, weight: .semibold, design: .monospaced)
        }
        return .system(size: fontSize, design: .monospaced)
    }

    private var lineNumberFont: Font {
        .system(size: fontSize, design: .monospaced)
    }
}
