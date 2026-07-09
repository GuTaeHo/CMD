import Foundation
import SwiftUI

/// 앱 안에서 선택할 수 있는 표시 언어.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case korean
    case english
    case japanese

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "시스템 언어"
        case .korean: return "한국어"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .korean: return "ko"
        case .english: return "en"
        case .japanese: return "ja"
        }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier ?? Locale.current.identifier)
    }

    var localizationCode: String? {
        switch self {
        case .system: return nil
        case .korean: return "ko"
        case .english: return "en"
        case .japanese: return "ja"
        }
    }
}

/// SwiftUI 환경 밖에서 필요한 문자열도 앱의 선택 언어를 따르게 해준다.
enum AppLocalization {
    static var language: AppLanguage = .system

    static func string(_ key: String, comment: String = "") -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func string(_ key: String, arguments: [CVarArg], comment: String = "") -> String {
        String(format: string(key, comment: comment), arguments: arguments)
    }

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        localizedBundle.url(forResource: name, withExtension: ext)
    }

    private static var localizedBundle: Bundle {
        guard let code = language.localizationCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
