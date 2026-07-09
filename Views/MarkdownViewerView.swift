import SwiftUI

/// 선택된 마크다운 문서를 렌더링해 보여주는 뷰어 화면.
struct MarkdownViewerView: View {
    let file: MarkdownFile
    @EnvironmentObject private var settings: AppSettings

    /// 활성화 시 마크다운 원본(raw)을 그대로 보여준다. 기본값은 렌더링 뷰(비활성화).
    @State private var showRawMarkdown = false

    /// 설정 시트 표시 여부.
    @State private var isSettingsPresented = false

    /// 파싱된 블록 캐시. 문서 내용이 바뀔 때만 다시 파싱하고,
    /// 글자 크기·행간·자간 같은 설정 변경 시에는 재파싱하지 않는다.
    /// (재파싱하면 블록마다 새 id 가 부여돼 뷰가 재생성되고, 이미지가 다시 로드된다.)
    @State private var blocks: [MarkdownBlock] = []

    /// 긴 원본 텍스트를 한 번에 레이아웃하지 않도록 청크 단위로 나눠 보관한다.
    @State private var rawChunks: [RawMarkdownChunk] = []

    /// 문서 준비 중 표시 여부.
    @State private var isPreparingDocument = false

    var body: some View {
        ScrollView {
            if showRawMarkdown {
                RawMarkdownSourceView(chunks: rawChunks,
                                      fontSize: settings.fontSize,
                                      isBoldTextEnabled: settings.resolvedIsBoldTextEnabled)
            } else {
                renderedMarkdownContent
            }
        }
        .task(id: file.id) {
            await prepareDocument()
        }
        .navigationTitle(file.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            SidebarToggleToolbarItem()
            #endif
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showRawMarkdown) {
                    Label("마크다운 원본", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .toggleStyle(.button)
                .help("마크다운 원본 보기")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Label("환경설정", systemImage: "gearshape")
                }
                .help("환경설정")
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            settingsSheet
        }
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
                                      letterSpacing: settings.letterSpacing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func prepareDocument() async {
        let content = file.content
        isPreparingDocument = true

        async let parsedBlocks = Task.detached(priority: .userInitiated) {
            MarkdownParser.parse(content)
        }.value

        async let sourceChunks = Task.detached(priority: .utility) {
            RawMarkdownChunk.makeChunks(from: content)
        }.value

        let prepared = await (parsedBlocks, sourceChunks)
        guard !Task.isCancelled else { return }

        blocks = prepared.0
        rawChunks = prepared.1
        isPreparingDocument = false
    }
}

/// 원본보기에서 SwiftUI 가 거대한 Text 하나를 계산하지 않도록 나눈 텍스트 조각.
private struct RawMarkdownChunk: Identifiable, Sendable {
    let id: Int
    let text: String

    static func makeChunks(from content: String, linesPerChunk: Int = 80) -> [RawMarkdownChunk] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        guard !lines.isEmpty else {
            return [RawMarkdownChunk(id: 0, text: " ")]
        }

        var chunks: [RawMarkdownChunk] = []
        chunks.reserveCapacity((lines.count / linesPerChunk) + 1)

        var index = 0
        while index < lines.count {
            let upperBound = min(index + linesPerChunk, lines.count)
            let chunkText = lines[index..<upperBound].joined(separator: "\n")
            chunks.append(RawMarkdownChunk(id: chunks.count,
                                           text: chunkText.isEmpty ? " " : chunkText))
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

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(chunks) { chunk in
                Text(verbatim: chunk.text)
                    .font(sourceFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var sourceFont: Font {
        if isBoldTextEnabled {
            return .system(size: fontSize, weight: .semibold, design: .monospaced)
        }
        return .system(size: fontSize, design: .monospaced)
    }
}
