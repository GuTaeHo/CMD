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

    var title: String {
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

/// 앱 전역 사용자 설정. UserDefaults 에 자동 저장된다.
final class AppSettings: ObservableObject {

    enum Key {
        static let fontSize = "settings.fontSize"
        static let lineSpacing = "settings.lineSpacing"
        static let letterSpacing = "settings.letterSpacing"
        static let appearanceMode = "settings.appearanceMode"
    }

    /// 뷰어 본문 기준 글자 크기 (pt)
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: Key.fontSize) }
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

    static let minFontSize: Double = 12
    static let maxFontSize: Double = 30
    static let defaultFontSize: Double = 17
    static let fontStep: Double = 1

    static let minLineSpacing: Double = 0
    static let maxLineSpacing: Double = 16
    static let defaultLineSpacing: Double = 5

    static let minLetterSpacing: Double = -1
    static let maxLetterSpacing: Double = 4
    static let defaultLetterSpacing: Double = 0

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.fontSize: AppSettings.defaultFontSize,
            Key.lineSpacing: AppSettings.defaultLineSpacing,
            Key.letterSpacing: AppSettings.defaultLetterSpacing,
            Key.appearanceMode: AppearanceMode.system.rawValue
        ])
        self.fontSize = defaults.double(forKey: Key.fontSize)
        self.lineSpacing = defaults.double(forKey: Key.lineSpacing)
        self.letterSpacing = defaults.double(forKey: Key.letterSpacing)
        let storedMode = defaults.string(forKey: Key.appearanceMode)
        self.appearanceMode = storedMode.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    /// 앱 전체에 적용할 색상 스킴. nil 이면 시스템 설정을 따른다.
    var resolvedColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    /// 시트에 적용할 색상 스킴. 시스템 모드도 현재 OS 설정을 읽어 명시적으로 적용한다.
    var resolvedPresentationColorScheme: ColorScheme {
        appearanceMode.colorScheme ?? Self.currentSystemColorScheme
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

    func resetFont() {
        fontSize = AppSettings.defaultFontSize
    }

    /// 행간·자간을 기본값으로 되돌린다.
    func resetSpacing() {
        lineSpacing = AppSettings.defaultLineSpacing
        letterSpacing = AppSettings.defaultLetterSpacing
    }
}
