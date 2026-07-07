import SwiftUI
import UniformTypeIdentifiers

/// 앱의 최상위 화면. 파일 목록을 네비게이션에 담고 환경설정 시트를 관리한다.
///
/// macOS 에서는 `.sheet` / `.fileImporter` 같은 모달을 사이드바 컬럼(`FileListView`)
/// 안에서 띄우면, 폭이 제한된 사이드바 레이아웃에 갇혀 시트가 찌그러지거나 파일 선택창이
/// 아예 표시되지 않는다. 그래서 모달 표시는 사이드바가 아니라 `NavigationView` 최상위에서
/// 처리하고, 툴바 버튼은 바인딩으로 상태만 토글한다.
struct RootView: View {
    @EnvironmentObject private var store: DocumentStore
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        return types
    }

    var body: some View {
        NavigationView {
            FileListView(isImporterPresented: $isImporterPresented,
                         isSettingsPresented: $isSettingsPresented)
                // macOS 사이드바(파일 목록) 너비 제한.
                #if os(macOS)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                #endif
            // macOS 에서는 사이드바 + 상세 형태로, iOS 에서는 스택 형태로 동작한다.
            #if os(macOS)
            PlaceholderDetailView()
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #else
        // macOS 앱 창의 최소 크기 제한.
        .frame(minWidth: 640, minHeight: 460)
        #endif
        // 모달은 사이드바가 아닌 NavigationView 최상위에 붙여야 macOS 에서 정상 표시된다.
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                store.import(urls: urls)
            case let .failure(error):
                store.lastError = error.localizedDescription
            }
        }
        .alert("오류", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("확인", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

#if os(macOS)
/// macOS 2단 레이아웃에서 아직 문서를 고르지 않았을 때 보이는 화면.
struct PlaceholderDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("왼쪽 목록에서 문서를 선택하세요")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
