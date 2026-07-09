# Agent Guide

Guidance for AI coding agents working in this repository. `AGENTS.md` and
`CLAUDE.md` are kept **in sync** — they must contain identical content. When you
edit one, apply the same change to the other.

## Project

CMD ("Cocoa Mark Down") is a SwiftUI multiplatform Markdown viewer for iOS and
macOS. It opens local `.md` / `.markdown` / `.txt` files, renders them with a
small in-house Markdown parser, and lets the user tune viewer typography (font
size, font family, weight, bold style, line/letter spacing), appearance
(light / dark / system), viewer extras (line count badge, raw-source view), and
app language (system / Korean / English / Japanese).

- Bundle identifier: `com.halftime.cmd`
- Language: Swift 5.0
- UI: SwiftUI (single codebase for iOS and macOS)
- Tooling: Xcode 15
- Dependencies: none — Apple frameworks only (`SwiftUI`, `Foundation`,
  `UniformTypeIdentifiers`). No Swift Package / CocoaPods / Carthage.

## Supported platforms

- iOS 15.0+
- macOS 12.0+
- Device families: iPhone, iPad, Mac

## Layout

All sources live at the repository root (there is intentionally **no** nested
`CMD/` source folder — files sit next to `CMD.xcodeproj`).

```
CMD.xcodeproj/            Xcode project (group-based file references)
CMDApp.swift              @main App entry; injects AppSettings + DocumentStore
CMD.entitlements          Sandbox + user-selected read-only file access
Assets.xcassets/          AppIcon, AccentColor
Models/
  AppSettings.swift       ObservableObject; typography/appearance/language/viewer
                          settings persisted to UserDefaults
  AppLocalization.swift   AppLanguage enum + runtime string/resource lookup that
                          follows the in-app language selection
  DocumentStore.swift     ObservableObject; open document list, file import
  MarkdownFile.swift      A single opened doc (content cached at open time)
  SampleContent.swift     Bundled welcome document (localized Welcome.md)
Markdown/
  MarkdownParser.swift    Line-based parser -> [MarkdownBlock]
  MarkdownBlockView.swift Renders a MarkdownBlock in SwiftUI
Views/
  RootView.swift          NavigationView root (2-column on macOS)
  FileListView.swift      Document list, fileImporter, swipe-to-delete, toolbar
  MarkdownViewerView.swift Rendered/raw-source viewer; async parse, line count
  SettingsView.swift      Typography, viewer, appearance, language settings
en.lproj/ ja.lproj/ ko.lproj/
                          Localizable.strings + localized Welcome.md per language
```

## Architecture notes

- State flows through two `@EnvironmentObject`s created in `CMDApp`:
  `AppSettings` (persisted to `UserDefaults`) and `DocumentStore` (open document
  list persisted to `UserDefaults`).
- Files are read **immediately** on selection and cached in `MarkdownFile` to
  avoid security-scoped-resource issues later; bookmark data is stored so the
  list can be restored after relaunch, and access is wrapped with
  `startAccessingSecurityScopedResource()` when available.
- `MarkdownParser` is a deliberately lightweight, line-based parser — **not** a
  full CommonMark implementation. It covers headings, paragraphs, bullet/ordered
  lists, code blocks, block quotes, images (Markdown + `<img>`), and horizontal
  rules. Extend it here when new syntax is needed.
- `MarkdownViewerView` prepares each document off the main thread
  (`Task.detached`): it parses blocks, splits the raw source into chunks for the
  raw-source view, and counts lines for the line count badge in one pass.
- Typography settings are combined into `AppSettings.viewerTypographyID`, which
  viewer text views attach via `.id()` so font changes re-render immediately.
  When adding new typography settings, include them in that identifier.
- Localization: user-facing strings are written in Korean and used as the
  localization keys (plus dotted keys like `viewer.line_count` for formatted
  strings). The app language can be overridden in-app (`AppLanguage`);
  `AppLocalization` resolves strings and resources from the selected `.lproj`
  bundle for code paths outside the SwiftUI environment.
- Platform differences are handled inline with `#if os(iOS)` / `#if os(macOS)`.

## Conventions

- Keep the codebase dependency-free; prefer Apple frameworks over adding
  packages.
- In-code comments and user-facing strings are written in Korean; keep that
  style when editing existing files.
- Every new user-facing string needs an entry in **all three** of
  `ko.lproj/Localizable.strings`, `en.lproj/Localizable.strings`, and
  `ja.lproj/Localizable.strings` (the key is the Korean string itself).
- The Xcode project uses classic PBXGroup references with
  `sourceTree = "<group>"`. When adding or moving files, update
  `CMD.xcodeproj/project.pbxproj` accordingly (build-file, file-reference,
  group, and Sources/Resources phase entries).

## Build & run

Open `CMD.xcodeproj` in Xcode and run, or from the command line:

```sh
# macOS
xcodebuild -project CMD.xcodeproj -scheme CMD -destination 'platform=macOS' build

# iOS simulator
xcodebuild -project CMD.xcodeproj -scheme CMD \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

There is currently no automated test target.
