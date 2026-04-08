# Markyd

Markyd is a macOS menu-bar app that turns copied sources into Markdown from a single global shortcut.

It currently supports three main workflows:

- Copied webpage URL: fetch HTML, convert to Markdown, then paste or copy the Markdown
- Copied remote PDF URL or known PDF-like link such as `arxiv.org/abs/...`: fetch PDF, convert to Markdown, then paste or copy the Markdown
- Copied Finder PDF file: convert the local PDF and write a sibling `.md` file next to the original PDF

The app is designed around a menu-bar-only workflow:

- Global shortcut: configurable preset, default `Command + Shift + M`
- Immediate menu-bar feedback: yellow while processing, green on success, red on failure
- Optional persistent history stored on disk, including clipboard source, fetched artifact, and Markdown output

## Current behavior

- If Accessibility permission is available, Markyd pastes the Markdown into the frontmost app.
- If Accessibility permission is missing or not usable for paste synthesis, Markyd still converts successfully and copies the Markdown back to the clipboard instead.
- If the clipboard already contains Markyd’s most recent generated Markdown, pressing the shortcut again is treated as a successful no-op.
- If a Finder-copied `.pdf` file is on the clipboard, Markyd writes `<same-name>.md` in the same folder instead of trying to paste.

## Key files

- [`Sources/Markyd/MarkydApp.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkydApp.swift): app entry, menu-bar label, icon feedback
- [`Sources/Markyd/MarkdownPasteCoordinator.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkdownPasteCoordinator.swift): main state machine and routing
- [`Sources/Markyd/ClipboardController.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/ClipboardController.swift): pasteboard input/output and synthetic paste
- [`Sources/Markyd/MarkdownConversionService.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkdownConversionService.swift): webpage/PDF conversion
- [`Sources/Markyd/HistoryStore.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/HistoryStore.swift): on-disk history archive
- [`Sources/MarkydCore/ClipboardURLClassifier.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/MarkydCore/ClipboardURLClassifier.swift): URL classification and special-case rewriting
- [`docs/architecture.md`](/Users/madhavajay/dev/markyd/main/Markyd/docs/architecture.md): detailed implementation notes

## Build

```bash
cd /Users/madhavajay/dev/markyd/main/Markyd
swift build
swift test
```

## Package app bundle

```bash
./Scripts/package_app.sh
```

This produces:

- [`Markyd.app`](/Users/madhavajay/dev/markyd/main/Markyd/Markyd.app)
