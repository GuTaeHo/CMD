import Foundation

/// 렌더링 단위가 되는 마크다운 블록의 종류.
enum MarkdownBlockKind: Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletList(items: [String])
    case orderedList(items: [OrderedItem])
    case codeBlock(code: String, language: String?)
    case quote(text: String)
    case image(source: String, alt: String?)
    case divider
}

struct OrderedItem: Sendable {
    let marker: String
    let text: String
}

/// Identifiable 을 위해 종류(kind)를 감싸는 값 타입.
struct MarkdownBlock: Identifiable, Sendable {
    let id = UUID()
    let kind: MarkdownBlockKind
}

/// 줄 단위로 마크다운을 훑어 블록 배열로 변환하는 가벼운 파서.
/// 완전한 CommonMark 구현이 아니라 뷰어에 필요한 핵심 문법만 다룬다.
enum MarkdownParser {

    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 빈 줄
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // 코드 블록 ```
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                index += 1 // 닫는 ``` 소비
                blocks.append(MarkdownBlock(kind: .codeBlock(
                    code: code.joined(separator: "\n"),
                    language: language.isEmpty ? nil : language)))
                continue
            }

            // 수평선
            if isHorizontalRule(trimmed) {
                blocks.append(MarkdownBlock(kind: .divider))
                index += 1
                continue
            }

            // 이미지 (한 줄이 통째로 이미지인 경우): <img ...> 또는 ![alt](url)
            if let image = parseImage(trimmed) {
                blocks.append(MarkdownBlock(kind: image))
                index += 1
                continue
            }

            // 제목 #
            if let heading = parseHeading(trimmed) {
                blocks.append(MarkdownBlock(kind: heading))
                index += 1
                continue
            }

            // 인용 >
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let t = lines[index].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    var content = String(t.dropFirst())
                    if content.hasPrefix(" ") { content.removeFirst() }
                    quoteLines.append(content)
                    index += 1
                }
                blocks.append(MarkdownBlock(kind: .quote(text: quoteLines.joined(separator: "\n"))))
                continue
            }

            // 순서 없는 목록 - * +
            if isBulletItem(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let t = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isBulletItem(t) else { break }
                    items.append(String(t.dropFirst(2)))
                    index += 1
                }
                blocks.append(MarkdownBlock(kind: .bulletList(items: items)))
                continue
            }

            // 순서 있는 목록 1. 2. ...
            if orderedMarker(trimmed) != nil {
                var items: [OrderedItem] = []
                while index < lines.count {
                    let t = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let marker = orderedMarker(t) else { break }
                    let text = String(t.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                    items.append(OrderedItem(marker: marker.trimmingCharacters(in: .whitespaces), text: text))
                    index += 1
                }
                blocks.append(MarkdownBlock(kind: .orderedList(items: items)))
                continue
            }

            // 문단: 다음 빈 줄/특수 블록 전까지 이어붙인다.
            var paragraphLines: [String] = []
            while index < lines.count {
                let raw = lines[index]
                let t = raw.trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("```") || t.hasPrefix(">")
                    || isBulletItem(t) || orderedMarker(t) != nil
                    || parseHeading(t) != nil || isHorizontalRule(t)
                    || parseImage(t) != nil {
                    break
                }
                paragraphLines.append(t)
                index += 1
            }
            if !paragraphLines.isEmpty {
                blocks.append(MarkdownBlock(kind: .paragraph(text: paragraphLines.joined(separator: "\n"))))
            }
        }

        return blocks
    }

    // MARK: - Helpers

    private static func parseHeading(_ line: String) -> MarkdownBlockKind? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for char in line {
            if char == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text)
    }

    /// 한 줄이 통째로 이미지일 때 (source, alt) 를 담은 image 블록을 반환.
    /// 지원 형식: `<img src="..." alt="...">` HTML 태그, `![alt](url)` 마크다운.
    private static func parseImage(_ line: String) -> MarkdownBlockKind? {
        // 1) HTML <img ...> 태그
        if line.lowercased().hasPrefix("<img"), line.hasSuffix(">") {
            guard let src = htmlAttribute("src", in: line) else { return nil }
            let alt = htmlAttribute("alt", in: line)
            return .image(source: src, alt: alt?.isEmpty == true ? nil : alt)
        }

        // 2) 마크다운 ![alt](url)
        if line.hasPrefix("!["),
           let bracketEnd = line.range(of: "]("),
           line.hasSuffix(")") {
            let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<bracketEnd.lowerBound])
            let source = String(line[bracketEnd.upperBound..<line.index(before: line.endIndex)])
                .trimmingCharacters(in: .whitespaces)
            guard !source.isEmpty else { return nil }
            return .image(source: source, alt: alt.isEmpty ? nil : alt)
        }

        return nil
    }

    /// HTML 태그 문자열에서 `name="value"` 또는 `name='value'` 속성 값을 추출.
    private static func htmlAttribute(_ name: String, in tag: String) -> String? {
        guard let nameRange = tag.range(of: name + "=", options: .caseInsensitive) else { return nil }
        var idx = nameRange.upperBound
        guard idx < tag.endIndex else { return nil }
        let quote = tag[idx]
        guard quote == "\"" || quote == "'" else { return nil }
        idx = tag.index(after: idx)
        var value = ""
        while idx < tag.endIndex, tag[idx] != quote {
            value.append(tag[idx])
            idx = tag.index(after: idx)
        }
        return value
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        return stripped.allSatisfy { $0 == "-" }
            || stripped.allSatisfy { $0 == "*" }
            || stripped.allSatisfy { $0 == "_" }
    }

    private static func isBulletItem(_ line: String) -> Bool {
        return line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    /// "12. " 같은 순서 목록 마커를 반환 (마커 문자열 포함, 없으면 nil)
    private static func orderedMarker(_ line: String) -> String? {
        var digits = ""
        var idx = line.startIndex
        while idx < line.endIndex, line[idx].isNumber {
            digits.append(line[idx])
            idx = line.index(after: idx)
        }
        guard !digits.isEmpty, idx < line.endIndex, line[idx] == "." else { return nil }
        let afterDot = line.index(after: idx)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        return "\(digits). "
    }
}
