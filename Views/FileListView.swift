import SwiftUI

/// 파일 선택 화면. 열어 본 문서 목록을 보여준다.
///
/// 파일 열기(`fileImporter`)와 환경설정(`sheet`) 모달은 macOS 호환을 위해 상위
/// `RootView` 의 NavigationView 최상위에서 표시한다. 여기서는 툴바 버튼으로 상태만 토글한다.
struct FileListView: View {
    @EnvironmentObject private var store: DocumentStore
    @Binding var isImporterPresented: Bool
    @Binding var isSettingsPresented: Bool

    var body: some View {
        Group {
            if store.files.isEmpty {
                emptyState
            } else {
                fileList
            }
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
                    Label("파일 열기", systemImage: "plus")
                }
            }
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
                NavigationLink {
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
                Label("마크다운 파일 열기", systemImage: "plus")
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
