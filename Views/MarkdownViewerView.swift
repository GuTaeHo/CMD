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

    var body: some View {
        ScrollView {
            if showRawMarkdown {
                Text(file.content)
                    .font(.system(size: settings.fontSize, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks) { block in
                        MarkdownBlockView(block: block,
                                          baseFontSize: settings.fontSize,
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
        .task(id: file.id) {
            blocks = MarkdownParser.parse(file.content)
        }
        .navigationTitle(file.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
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
}
