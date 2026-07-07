import SwiftUI

/// 파싱된 블록 하나를 SwiftUI 로 렌더링한다.
struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let baseFontSize: Double
    /// 줄 사이 간격 (행간, pt)
    var lineSpacing: Double = AppSettings.defaultLineSpacing
    /// 글자 사이 간격 (자간, pt)
    var letterSpacing: Double = AppSettings.defaultLetterSpacing

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            Text(inlineAttributed(text))
                .tracked(letterSpacing)
                .font(.system(size: headingSize(for: level), weight: .bold))
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? 6 : 2)

        case let .paragraph(text):
            Text(inlineAttributed(text))
                .tracked(letterSpacing)
                .font(.system(size: baseFontSize))
                .lineSpacing(lineSpacing)
                .fixedSize(horizontal: false, vertical: true)

        case let .bulletList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.system(size: baseFontSize, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text(inlineAttributed(item))
                            .tracked(letterSpacing)
                            .font(.system(size: baseFontSize))
                            .lineSpacing(lineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.marker)
                            .font(.system(size: baseFontSize, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text(inlineAttributed(entry.text))
                            .tracked(letterSpacing)
                            .font(.system(size: baseFontSize))
                            .lineSpacing(lineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case let .codeBlock(code, language):
            VStack(alignment: .leading, spacing: 4) {
                if let language {
                    Text(language.uppercased())
                        .font(.system(size: baseFontSize * 0.7, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: baseFontSize * 0.9, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
            )

        case let .quote(text):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 4)
                Text(inlineAttributed(text))
                    .tracked(letterSpacing)
                    .font(.system(size: baseFontSize))
                    .italic()
                    .foregroundColor(.secondary)
                    .lineSpacing(lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

        case let .image(source, alt):
            MarkdownImageView(source: source, alt: alt, baseFontSize: baseFontSize)

        case .divider:
            Divider()
                .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func headingSize(for level: Int) -> Double {
        switch level {
        case 1: return baseFontSize * 1.8
        case 2: return baseFontSize * 1.5
        case 3: return baseFontSize * 1.3
        case 4: return baseFontSize * 1.15
        default: return baseFontSize * 1.05
        }
    }

    // (이미지 렌더링은 MarkdownImageView 로 분리)

    /// 인라인 마크다운(**굵게**, *기울임*, `코드`, [링크]) 을 AttributedString 으로 변환.
    private func inlineAttributed(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return attributed
        }
        return AttributedString(string)
    }
}

private extension Text {
    /// 자간(글자 사이 간격)을 적용한다. `tracking` 은 iOS 16 / macOS 13 이상에서만
    /// 지원하므로, 그 미만에서는 자간 조정 없이 원본 그대로 렌더링한다.
    func tracked(_ value: Double) -> Text {
        if #available(iOS 16.0, macOS 13.0, *) {
            return self.tracking(value)
        } else {
            return self
        }
    }
}

/// 마크다운/HTML 이미지 소스를 실제 이미지로 렌더링한다.
/// - 원격 URL(http/https): `AsyncImage` 로 비동기 로드
/// - 로컬 파일 경로 / file:// URL: 디스크에서 로드
/// - 그 외 문자열: 앱 번들 에셋 이름으로 시도
struct MarkdownImageView: View {
    let source: String
    let alt: String?
    let baseFontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let alt, !alt.isEmpty {
                Text(alt)
                    .font(.system(size: baseFontSize * 0.8))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        if let url = remoteURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    placeholder(systemImage: "photo.badge.exclamationmark", text: "이미지를 불러올 수 없습니다")
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        } else if let platformImage = localImage {
            platformImage
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholder(systemImage: "photo", text: source)
        }
    }

    private func placeholder(systemImage: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.system(size: baseFontSize * 0.85))
                .lineLimit(2)
        }
        .foregroundColor(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
    }

    /// http/https 원격 URL 이면 반환.
    private var remoteURL: URL? {
        guard let url = URL(string: source),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    /// 로컬 파일 경로 / file:// / 번들 에셋에서 이미지를 찾아 SwiftUI Image 로 반환.
    private var localImage: Image? {
        // file:// URL 또는 절대 경로
        if let fileURL = fileURL {
            #if os(macOS)
            if let ns = NSImage(contentsOf: fileURL) { return Image(nsImage: ns) }
            #else
            if let data = try? Data(contentsOf: fileURL), let ui = UIImage(data: data) {
                return Image(uiImage: ui)
            }
            #endif
        }
        // 앱 번들 에셋 이름
        #if os(macOS)
        if NSImage(named: source) != nil { return Image(source) }
        #else
        if UIImage(named: source) != nil { return Image(source) }
        #endif
        return nil
    }

    private var fileURL: URL? {
        if source.hasPrefix("file://") { return URL(string: source) }
        if source.hasPrefix("/") { return URL(fileURLWithPath: source) }
        return nil
    }
}
