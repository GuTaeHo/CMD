import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 화면 모드. 라이트 / 다크 / 시스템 3종.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .light: return "라이트"
        case .dark: return "다크"
        case .system: return "시스템"
        }
    }

    /// 적용할 색상 스킴. nil 이면 시스템 설정을 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// 뷰어에 적용할 서체 프리셋.
enum ViewerFontFamily: String, CaseIterable, Identifiable {
    case system
    case appleSDGothicNeo
    case appleMyungjo = "serif"
    case rounded
    case monospaced

    var id: String { rawValue }

    var title: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }

    var localizationKey: String {
        switch self {
        case .system: return "시스템 서체"
        case .appleSDGothicNeo: return "Apple SD 산돌고딕 Neo"
        case .appleMyungjo: return "AppleMyungjo"
        case .rounded: return "둥근 서체"
        case .monospaced: return "고정폭 서체"
        }
    }

    func font(size: Double,
              weight: Font.Weight? = nil,
              sandollWeight: ViewerSandollFontWeight = AppSettings.defaultSandollFontWeight) -> Font {
        switch self {
        case .system:
            return systemFont(size: size, weight: weight, design: .default)
        case .appleSDGothicNeo:
            return .custom(sandollWeight.adjusted(for: weight).postScriptName, size: size)
        case .appleMyungjo:
            return .custom("AppleMyungjo", size: size)
        case .rounded:
            return systemFont(size: size, weight: weight, design: .rounded)
        case .monospaced:
            return systemFont(size: size, weight: weight, design: .monospaced)
        }
    }

    private func systemFont(size: Double, weight: Font.Weight?, design: Font.Design) -> Font {
        if let weight {
            return .system(size: size, weight: weight, design: design)
        }
        return .system(size: size, design: design)
    }

}

/// Apple SD 산돌고딕 Neo 에서 선택할 수 있는 실제 굵기.
enum ViewerSandollFontWeight: String, CaseIterable, Identifiable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold

    var id: String { rawValue }

    var title: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }

    var localizationKey: String {
        switch self {
        case .ultraLight: return "아주 옅게"
        case .thin: return "얇게"
        case .light: return "옅게"
        case .regular: return "일반"
        case .medium: return "중간"
        case .semibold: return "세미볼드"
        case .bold: return "볼드"
        }
    }

    var postScriptName: String {
        switch self {
        case .ultraLight: return "AppleSDGothicNeo-UltraLight"
        case .thin: return "AppleSDGothicNeo-Thin"
        case .light: return "AppleSDGothicNeo-Light"
        case .regular: return "AppleSDGothicNeo-Regular"
        case .medium: return "AppleSDGothicNeo-Medium"
        case .semibold: return "AppleSDGothicNeo-SemiBold"
        case .bold: return "AppleSDGothicNeo-Bold"
        }
    }

    func adjusted(for weight: Font.Weight?) -> ViewerSandollFontWeight {
        guard let weight else { return self }

        switch weight {
        case .bold:
            return atLeast(.bold)
        case .semibold:
            return heavier().atLeast(.semibold)
        case .medium:
            return atLeast(.medium)
        case .heavy, .black:
            return .bold
        case .light:
            return atLeast(.light)
        case .thin:
            return atLeast(.thin)
        case .ultraLight:
            return atLeast(.ultraLight)
        default:
            return self
        }
    }

    private var rank: Int {
        Self.allCases.firstIndex(of: self) ?? 3
    }

    private func atLeast(_ minimum: ViewerSandollFontWeight) -> ViewerSandollFontWeight {
        rank < minimum.rank ? minimum : self
    }

    private func heavier() -> ViewerSandollFontWeight {
        let index = min(rank + 1, Self.allCases.count - 1)
        return Self.allCases[index]
    }

    static func load(rawValue: String?) -> ViewerSandollFontWeight {
        guard let rawValue else { return AppSettings.defaultSandollFontWeight }

        switch rawValue {
        case "extraBold", "heavy":
            return .bold
        default:
            return ViewerSandollFontWeight(rawValue: rawValue) ?? AppSettings.defaultSandollFontWeight
        }
    }
}

/// 뷰어 본문 굵기 표시 방식.
enum ViewerBoldTextStyle: String, CaseIterable, Identifiable {
    case normal
    case bold
    case system

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .normal: return "보통"
        case .bold: return "굵게"
        case .system: return "시스템"
        }
    }
}

/// 앱 전역 사용자 설정. UserDefaults 에 자동 저장된다.
final class AppSettings: ObservableObject {

    enum Key {
        static let fontSize = "settings.fontSize"
        static let fontFamily = "settings.fontFamily"
        static let sandollFontWeight = "settings.sandollFontWeight"
        static let boldTextStyle = "settings.boldTextStyle"
        static let isBoldTextEnabled = "settings.isBoldTextEnabled"
        static let lineSpacing = "settings.lineSpacing"
        static let letterSpacing = "settings.letterSpacing"
        static let appearanceMode = "settings.appearanceMode"
        static let appLanguage = "settings.appLanguage"
        static let showLineCount = "settings.showLineCount"
        static let showLineNumbers = "settings.showLineNumbers"
    }

    /// 뷰어 본문 기준 글자 크기 (pt)
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: Key.fontSize) }
    }

    /// 뷰어 본문 서체 프리셋.
    @Published var fontFamily: ViewerFontFamily {
        didSet { UserDefaults.standard.set(fontFamily.rawValue, forKey: Key.fontFamily) }
    }

    /// Apple SD 산돌고딕 Neo 의 기본 굵기.
    @Published var sandollFontWeight: ViewerSandollFontWeight {
        didSet { UserDefaults.standard.set(sandollFontWeight.rawValue, forKey: Key.sandollFontWeight) }
    }

    /// 본문과 원본 보기의 굵기 표시 방식.
    @Published var boldTextStyle: ViewerBoldTextStyle {
        didSet { UserDefaults.standard.set(boldTextStyle.rawValue, forKey: Key.boldTextStyle) }
    }

    /// 줄 사이 간격, 행간 (pt)
    @Published var lineSpacing: Double {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: Key.lineSpacing) }
    }

    /// 글자 사이 간격, 자간 (pt)
    @Published var letterSpacing: Double {
        didSet { UserDefaults.standard.set(letterSpacing, forKey: Key.letterSpacing) }
    }

    /// 화면 모드 (라이트/다크/시스템)
    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Key.appearanceMode) }
    }

    /// 뷰어에 문서 전체 줄 수를 표시할지 여부.
    @Published var showLineCount: Bool {
        didSet { UserDefaults.standard.set(showLineCount, forKey: Key.showLineCount) }
    }

    /// 마크다운 원본 보기에서 각 줄 옆에 줄 번호를 표시할지 여부.
    @Published var showLineNumbers: Bool {
        didSet { UserDefaults.standard.set(showLineNumbers, forKey: Key.showLineNumbers) }
    }

    /// 앱 표시 언어 (시스템/한국어/영어/일본어)
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Key.appLanguage)
            AppLocalization.language = appLanguage
        }
    }

    static let minFontSize: Double = 12
    static let maxFontSize: Double = 30
    static let defaultFontSize: Double = 17
    static let fontStep: Double = 1
    static let defaultFontFamily: ViewerFontFamily = .system
    static let defaultSandollFontWeight: ViewerSandollFontWeight = .regular
    static let defaultBoldTextStyle: ViewerBoldTextStyle = .system

    static let minLineSpacing: Double = 0
    static let maxLineSpacing: Double = 16
    static let defaultLineSpacing: Double = 5

    static let minLetterSpacing: Double = -1
    static let maxLetterSpacing: Double = 4
    static let defaultLetterSpacing: Double = 0

    static let defaultShowLineCount = true
    static let defaultShowLineNumbers = true

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.fontSize: AppSettings.defaultFontSize,
            Key.fontFamily: AppSettings.defaultFontFamily.rawValue,
            Key.sandollFontWeight: AppSettings.defaultSandollFontWeight.rawValue,
            Key.boldTextStyle: AppSettings.defaultBoldTextStyle.rawValue,
            Key.lineSpacing: AppSettings.defaultLineSpacing,
            Key.letterSpacing: AppSettings.defaultLetterSpacing,
            Key.appearanceMode: AppearanceMode.system.rawValue,
            Key.appLanguage: AppLanguage.system.rawValue,
            Key.showLineCount: AppSettings.defaultShowLineCount,
            Key.showLineNumbers: AppSettings.defaultShowLineNumbers
        ])
        self.fontSize = defaults.double(forKey: Key.fontSize)
        let storedFontFamily = defaults.string(forKey: Key.fontFamily)
        self.fontFamily = storedFontFamily.flatMap(ViewerFontFamily.init(rawValue:)) ?? .system
        let storedSandollFontWeight = defaults.string(forKey: Key.sandollFontWeight)
        self.sandollFontWeight = ViewerSandollFontWeight.load(rawValue: storedSandollFontWeight)
        self.boldTextStyle = Self.loadBoldTextStyle(from: defaults)
        self.lineSpacing = defaults.double(forKey: Key.lineSpacing)
        self.letterSpacing = defaults.double(forKey: Key.letterSpacing)
        let storedMode = defaults.string(forKey: Key.appearanceMode)
        self.appearanceMode = storedMode.flatMap(AppearanceMode.init(rawValue:)) ?? .system
        let storedLanguage = defaults.string(forKey: Key.appLanguage)
        self.appLanguage = storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.showLineCount = defaults.bool(forKey: Key.showLineCount)
        self.showLineNumbers = defaults.bool(forKey: Key.showLineNumbers)
        AppLocalization.language = appLanguage
    }

    /// 앱 전체에 적용할 색상 스킴. nil 이면 시스템 설정을 따른다.
    var resolvedColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    /// 시트에 적용할 색상 스킴. 시스템 모드도 현재 OS 설정을 읽어 명시적으로 적용한다.
    var resolvedPresentationColorScheme: ColorScheme {
        appearanceMode.colorScheme ?? Self.currentSystemColorScheme
    }

    /// 앱 전체에 적용할 Locale. `.system` 이면 현재 OS 언어를 따른다.
    var resolvedLocale: Locale {
        appLanguage.locale
    }

    /// 현재 설정을 실제 굵게 표시 여부로 해석한다.
    var resolvedIsBoldTextEnabled: Bool {
        switch boldTextStyle {
        case .normal: return false
        case .bold: return true
        case .system: return Self.systemBoldTextEnabled
        }
    }

    /// 뷰어 텍스트 렌더링을 즉시 갱신하기 위한 식별자.
    var viewerTypographyID: String {
        [
            String(format: "%.2f", fontSize),
            fontFamily.rawValue,
            sandollFontWeight.rawValue,
            boldTextStyle.rawValue,
            String(resolvedIsBoldTextEnabled),
            String(format: "%.2f", lineSpacing),
            String(format: "%.2f", letterSpacing)
        ].joined(separator: "|")
    }

    /// 현재 OS 의 실제 라이트/다크 모드.
    private static var currentSystemColorScheme: ColorScheme {
        #if os(macOS)
        let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .darkAqua ? .dark : .light
        #elseif os(iOS)
        let style = UIScreen.main.traitCollection.userInterfaceStyle
        return style == .dark ? .dark : .light
        #else
        return .light
        #endif
    }

    /// OS 의 굵은 텍스트 접근성 설정. macOS 에서는 별도 대응 API 가 없어 보통으로 본다.
    private static var systemBoldTextEnabled: Bool {
        #if os(iOS)
        UIAccessibility.isBoldTextEnabled
        #else
        false
        #endif
    }

    /// 이전 버전의 Bool 설정을 새 3단계 설정으로 옮겨 읽는다.
    private static func loadBoldTextStyle(from defaults: UserDefaults) -> ViewerBoldTextStyle {
        if let storedStyle = defaults.string(forKey: Key.boldTextStyle),
           let style = ViewerBoldTextStyle(rawValue: storedStyle) {
            return style
        }

        if defaults.object(forKey: Key.isBoldTextEnabled) != nil {
            return defaults.bool(forKey: Key.isBoldTextEnabled) ? .bold : .normal
        }

        return AppSettings.defaultBoldTextStyle
    }

    func resetFont() {
        fontSize = AppSettings.defaultFontSize
        fontFamily = AppSettings.defaultFontFamily
        sandollFontWeight = AppSettings.defaultSandollFontWeight
        boldTextStyle = AppSettings.defaultBoldTextStyle
    }

    /// 행간·자간을 기본값으로 되돌린다.
    func resetSpacing() {
        lineSpacing = AppSettings.defaultLineSpacing
        letterSpacing = AppSettings.defaultLetterSpacing
    }
}
