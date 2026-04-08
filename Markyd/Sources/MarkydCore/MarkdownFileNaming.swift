import Foundation

public enum MarkdownFileNaming {
    public static func outputURL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(baseName).md")
    }
}
