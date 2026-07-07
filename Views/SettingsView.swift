import SwiftUI

/// 환경설정 화면. 글자 크기 조정과 화면 모드 전환을 제공한다.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            // sheet 는 별도 presentation 컨텍스트라 RootView 의 preferredColorScheme 가
            // 전파되지 않는다. 모드 변경이 sheet 안에서도 즉시 반영되도록 여기서도 적용한다.
            .preferredColorScheme(settings.resolvedColorScheme)
    }

    // macOS 와 iOS 는 시트 레이아웃이 달라 각각 다르게 감싼다.
    // macOS 에서 NavigationView 로 감싸면 사이드바 형태로 렌더되어 화면이 깨진다.
    #if os(macOS)
    private var content: some View {
        VStack(spacing: 0) {
            Text("환경설정")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            Divider()

            settingsForm

            Divider()

            HStack {
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420, height: 560)
    }
    #else
    private var content: some View {
        NavigationView {
            settingsForm
                .navigationTitle("환경설정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { dismiss() }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
    #endif

    private var settingsForm: some View {
        Form {
            Section("글자 크기") {
                HStack {
                    Text("가나다 Aa")
                        .font(.system(size: settings.fontSize))
                    Spacer()
                }

                Stepper(value: $settings.fontSize,
                        in: AppSettings.minFontSize...AppSettings.maxFontSize,
                        step: AppSettings.fontStep) {
                    HStack {
                        Text("글자 크기")
                        Spacer()
                        Text("\(Int(settings.fontSize)) pt")
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }

                Button("기본값으로 되돌리기") {
                    settings.resetFont()
                }
            }

            Section("행간 · 자간") {
                spacingPreview

                spacingSlider(title: "행간",
                              systemImage: "arrow.up.and.down",
                              value: $settings.lineSpacing,
                              range: AppSettings.minLineSpacing...AppSettings.maxLineSpacing,
                              step: 0.5)

                spacingSlider(title: "자간",
                              systemImage: "arrow.left.and.right",
                              value: $settings.letterSpacing,
                              range: AppSettings.minLetterSpacing...AppSettings.maxLetterSpacing,
                              step: 0.1)

                letterSpacingUnavailableNotice

                Button("기본값으로 되돌리기") {
                    settings.resetSpacing()
                }
            }

            Section("화면 모드") {
                Picker("화면 모드", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                HStack {
                    Text("앱 버전")
                    Spacer()
                    Text(Self.appVersion)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 자간(`tracking`)을 지원하지 않는 구버전에서만 보이는 안내 문구.
    /// iOS 16 / macOS 13 이상에서는 아무것도 표시하지 않는다.
    @ViewBuilder
    private var letterSpacingUnavailableNotice: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            EmptyView()
        } else {
            #if os(macOS)
            let requirement = "macOS 13"
            #else
            let requirement = "iOS 16"
            #endif
            Text("자간 조정은 \(requirement) 이상에서 지원합니다.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    /// 행간/자간 조절용 슬라이더 행. 현재 값(pt)을 함께 표시한다.
    private func spacingSlider(title: String, systemImage: String,
                               value: Binding<Double>,
                               range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(String(format: "%.1f pt", value.wrappedValue))
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    /// 행간·자간 조정 결과를 미리 보여주는 예시 텍스트.
    private var spacingPreview: some View {
        previewText
            .font(.system(size: settings.fontSize))
            .lineSpacing(settings.lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 자간 적용 예시 텍스트. `tracking` 은 iOS 16 / macOS 13 이상에서만 지원한다.
    private var previewText: Text {
        let sample = Text("가나다라마 ABCabc\n행간과 자간 미리보기")
        if #available(iOS 16.0, macOS 13.0, *) {
            return sample.tracking(settings.letterSpacing)
        } else {
            return sample
        }
    }

    /// 앱 버전 문자열 (예: "1.0 (1)"). Info.plist 값을 사용한다.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }
}
