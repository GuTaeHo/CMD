import SwiftUI

/// 새 마크다운 문서를 작성하는 화면.
///
/// macOS 호환을 위해 시트 표시는 `RootView` 에서 하고, 여기서는 입력과 저장만 담당한다.
struct NewDocumentView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var content = ""

    /// 이름과 내용이 모두 비어 있으면 저장할 것이 없다.
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        // macOS 에서 NavigationView 로 감싸면 사이드바 형태로 렌더되어 화면이 깨진다.
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text("새 마크다운 문서")
                    .font(.headline)
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("저장") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding()
            Divider()
            editor
        }
        .frame(width: 520, height: 480)
        #else
        NavigationView {
            editor
                .navigationTitle("새 마크다운 문서")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") { save() }
                            .disabled(!canSave)
                    }
                }
        }
        .navigationViewStyle(.stack)
        #endif
    }

    private var editor: some View {
        VStack(spacing: 0) {
            TextField("문서 이름", text: $name)
                .textFieldStyle(.plain)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            Divider()
            TextEditor(text: $content)
                .font(.body.monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // iOS 15 의 TextEditor 는 플레이스홀더가 없어 직접 겹쳐 그린다.
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("내용을 입력하세요")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func save() {
        store.createDocument(name: name, content: content)
        dismiss()
    }
}
