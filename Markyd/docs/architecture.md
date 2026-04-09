# Markyd Architecture

This document captures the current implementation and behavior of Markyd as built in this repository.

## Product summary

Markyd is a menu-bar-only macOS app that reacts to a global shortcut and converts whatever useful source is currently on the clipboard into Markdown.

The intent is:

- Copy a webpage URL, PDF URL, or Finder PDF file
- Press the Markyd shortcut
- Get Markdown either pasted into the active app, copied to the clipboard, or written beside the source PDF on disk

## Main flow

The main control path lives in [`MarkdownPasteCoordinator.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkdownPasteCoordinator.swift).

High-level sequence:

1. Global hotkey fires
2. Coordinator records a visible “shortcut received” state
3. Coordinator asks the clipboard controller for the current payload
4. Payload is routed through conversion service
5. Output is delivered via one of these sinks:
   - synthetic paste into the frontmost app
   - clipboard writeback only
   - sibling `.md` file beside a Finder-copied PDF
6. Attempt is optionally archived into history
7. Menu-bar icon flashes success or failure

## Clipboard input model

Clipboard reads are handled by [`ClipboardController.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/ClipboardController.swift).

The controller currently recognizes:

- `string`: normal plain-text clipboard content
- `fileURL`: a file copied from Finder, detected from pasteboard URL types

Behavior:

- If Finder copied a `.pdf`, the clipboard controller returns `.fileURL(URL)`
- Otherwise, it falls back to a plain string

This distinction matters because Finder PDF copies are treated as filesystem-output workflows, not paste workflows.

## Conversion routing

Routing logic is split between:

- [`ClipboardURLClassifier.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/MarkydCore/ClipboardURLClassifier.swift)
- [`MarkdownConversionService.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkdownConversionService.swift)

### Supported routes

1. Webpage URL

- Input: `https://example.com/...`
- Action: fetch HTML
- Conversion: local `Demark` using the `html-to-md` engine

2. Remote PDF URL

- Input: direct `.pdf` URL or PDF-like URL
- Action: fetch PDF bytes
- Conversion: local PDF converter path

3. Special URL rewritten to PDF

- Example: `https://arxiv.org/abs/...`
- Action: rewritten to `https://arxiv.org/pdf/...pdf`
- Then routed through the PDF path

4. Local Finder PDF file

- Input: Finder-copied file URL ending in `.pdf`
- Action: read file locally
- Conversion: local PDF converter path
- Output: sibling `.md` file in same folder

### Why webpage conversion uses `html-to-md`

Markyd originally used Demark’s Turndown/WebKit path for webpage conversion. That crashed in practice inside `WKWebView.evaluateJavaScript` on some pages. The current implementation intentionally uses:

- `DemarkOptions(engine: .htmlToMd)`

This avoids the WebKit crash path and is the stable default for Markyd right now.

## PDF conversion path

PDF conversion is abstracted by [`PDFMarkdownConverting.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/MarkydCore/PDFMarkdownConverting.swift).

Current implementation:

- [`PDFKitMarkdownConverter` in `MarkdownConversionService.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkdownConversionService.swift)

What it does:

- Opens PDF with `PDFDocument`
- Extracts text page by page
- Emits simple Markdown with `## Page N` sections

Why this is structured this way:

- The local fallback works today
- A future external PDF-to-Markdown library can replace only the converter implementation while keeping the rest of Markyd stable

## Output sinks

Markyd currently has three output modes.

### 1. Paste into frontmost app

Used when:

- source is URL-based
- Accessibility permission is available
- workflow is not a Finder PDF file

Implementation:

- `ClipboardController.pasteString`
- writes temporary clipboard contents
- synthesizes `Command + V`
- restores prior clipboard contents after a short delay

### 2. Copy Markdown back to clipboard

Used when:

- conversion succeeds
- Accessibility is unavailable or unusable for synthetic paste

This ensures conversion still works even when auto-paste cannot.

### 3. Write sibling `.md` file

Used when:

- the clipboard payload is a local Finder-copied PDF file

Naming:

- derived by [`MarkdownFileNaming.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/MarkydCore/MarkdownFileNaming.swift)
- `/path/file.pdf` becomes `/path/file.md`

## Hotkey and feedback

Hotkey settings live in [`HotKeySettings.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/HotKeySettings.swift).

Current default:

- `Command + Shift + M`

Registration is handled by [`GlobalHotKeyManager.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/GlobalHotKeyManager.swift).

The app exposes:

- current selected preset
- registration success or failure message
- last time the shortcut was received

### Menu-bar icon feedback

The menu-bar symbol is rendered in [`MarkydApp.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/MarkydApp.swift).

Current visual states:

- idle: normal monochrome
- processing: yellow pulse
- success: green pulse
- failure: red pulse

There is also an explicit no-op success case:

- If the clipboard already contains Markyd’s latest generated Markdown, pressing the shortcut again does not reconvert and is treated as a successful no-op

## History

History is controlled by [`HistorySettings.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/HistorySettings.swift).

When enabled, each attempt is archived by [`HistoryStore.swift`](/Users/madhavajay/dev/markyd/main/Markyd/Sources/Markyd/HistoryStore.swift).

Storage location:

- `~/Library/Application Support/Markyd/History`

Per-attempt folder contents may include:

- `clipboard.txt`: the raw clipboard source
- `source.html` or `source.pdf`: fetched artifact when available
- `output.md`: generated Markdown when conversion succeeded
- `metadata.json`: attempt metadata

The menu shows recent history items and allows:

- reopening the history root folder
- pasting a saved Markdown result back into the active app

## Permissions

### Accessibility

Used only for synthetic paste into other apps.

If unavailable:

- Markyd still converts
- Markyd falls back to copying Markdown to the clipboard

### Network

Used for:

- webpage fetch
- remote PDF fetch

Local Finder PDF conversion does not require network.

## Known tradeoffs and current limitations

1. Webpage conversion currently prefers stability over DOM accuracy.
   Markyd uses Demark’s `html-to-md` engine instead of the WebKit/Turndown path because the latter crashed in real use.

2. PDF conversion is intentionally basic right now.
   The `PDFKit` fallback extracts page text, but it is not a layout-preserving Markdown conversion.

3. Shortcut conflict detection is limited.
   Markyd can report whether Carbon hotkey registration succeeded, but it cannot authoritatively inspect every app-specific shortcut on the machine.

4. Finder file support currently targets PDFs.
   Other file types are not yet routed through special filesystem output logic.

5. History writes raw artifacts to disk.
   This is intentional for recoverability and debugging, but users should treat history as local stored content, not ephemeral clipboard memory.

## Suggested next implementation steps

If Markyd continues evolving, the most logical next steps are:

1. Replace `PDFKitMarkdownConverter` with a stronger external PDF-to-Markdown converter.
2. Add richer special-URL rewriting rules beyond arXiv.
3. Add per-history-item “Reveal in Finder” and “Copy Markdown” actions.
4. Add explicit file overwrite policy for existing sibling `.md` files.
5. Add structured logs around fetch timing and converter choice.
