import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

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
    @State private var isNewDocumentPresented = false
    @State private var isDropTargeted = false

    /// 드롭으로 받는 타입. 파일 URL(파인더)과 문서 내용 표현(파일 앱)을 모두 허용한다.
    private var dropTypes: [UTType] {
        [.fileURL] + DocumentStore.supportedTypes
    }

    var body: some View {
        NavigationView {
            FileListView(isImporterPresented: $isImporterPresented,
                         isSettingsPresented: $isSettingsPresented,
                         isNewDocumentPresented: $isNewDocumentPresented)
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
        .sheet(isPresented: $isNewDocumentPresented) {
            NewDocumentView()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: DocumentStore.supportedTypes,
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
        // 파인더/파일 앱에서 창 위로 마크다운 파일을 끌어다 놓으면 바로 연다.
        .onDrop(of: dropTypes, isTargeted: $isDropTargeted) { providers in
            store.importDropped(providers: providers)
        }
        .overlay(dropTargetOverlay)
    }

    /// 드롭 대상 위에 파일을 끌고 있는 동안 표시하는 안내 오버레이.
    @ViewBuilder
    private var dropTargetOverlay: some View {
        if isDropTargeted {
            ZStack {
                Color.accentColor.opacity(0.08)
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 44))
                    Text("여기에 놓아 문서 열기")
                        .font(.headline)
                }
                .foregroundColor(.accentColor)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(8)
            )
            .allowsHitTesting(false)
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
        .toolbar {
            SidebarToggleToolbarItem()
        }
    }
}

/// macOS 사이드바를 접거나 펼치는 툴바 버튼.
struct SidebarToggleToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)),
                                 to: nil,
                                 from: nil)
            } label: {
                Label("사이드바", systemImage: "sidebar.left")
            }
            .help("사이드바 접기/펴기")
        }
    }
}
#endif
