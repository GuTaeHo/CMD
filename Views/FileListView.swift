import SwiftUI

/// 파일 선택 화면. 열어 본 문서 목록을 보여준다.
///
/// 파일 열기(`fileImporter`)와 환경설정(`sheet`) 모달은 macOS 호환을 위해 상위
/// `RootView` 의 NavigationView 최상위에서 표시한다. 여기서는 툴바 버튼으로 상태만 토글한다.
struct FileListView: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var isImporterPresented: Bool
    @Binding var isSettingsPresented: Bool
    @Binding var isNewDocumentPresented: Bool

    var body: some View {
        Group {
            if store.files.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        // 새 문서 작성 플로팅 버튼 (우측 하단)
        .overlay(alignment: .bottomTrailing) {
            newDocumentButton
        }
        .navigationTitle("CMD")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Label("환경설정", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: openButtonPlacement) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("파일 열기", systemImage: "folder")
                }
            }
        }
    }

    /// 새 마크다운 문서 작성 화면을 여는 플로팅 버튼.
    private var newDocumentButton: some View {
        newDocumentButtonBase
            .padding(20)
            .accessibilityLabel(Text("새 문서 만들기"))
            .help("새 문서 만들기")
    }

    /// 시스템 filled 스타일(.borderedProminent)에 원형 보더 셰이프를 적용한 버튼.
    /// .circle 은 iOS 17 / macOS 14 부터 지원되므로 이전 OS 는 capsule 로 대체한다.
    @ViewBuilder
    private var newDocumentButtonBase: some View {
        let base = Button {
            isNewDocumentPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        if #available(iOS 17.0, macOS 14.0, *) {
            base.buttonBorderShape(.circle)
        } else {
            #if os(iOS)
            base.buttonBorderShape(.capsule)
            #else
            base
            #endif
        }
    }

    private var openButtonPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarLeading
        #else
        return .automatic
        #endif
    }

    private var fileList: some View {
        List {
            ForEach(store.files) { file in
                // selection 바인딩을 쓰면 파일을 가져온 직후 store 가 선택을 지정해 바로 열 수 있다.
                NavigationLink(tag: file.id, selection: $store.selectedFileID) {
                    MarkdownViewerView(file: file)
                } label: {
                    FileRow(file: file)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.remove(file)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("열린 문서가 없습니다")
                .font(.headline)
            Button {
                isImporterPresented = true
            } label: {
                Label("마크다운 파일 열기", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// 목록의 한 행.
private struct FileRow: View {
    let file: MarkdownFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .foregroundColor(.primary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                Text(file.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
