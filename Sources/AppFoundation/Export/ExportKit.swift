import Foundation

public enum ExportImageFormat: Sendable, Equatable {
    case png
    case jpeg(quality: Double)

    public var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        }
    }
}

public struct ExportFile: Sendable, Equatable {
    public let url: URL
    public let suggestedFilename: String

    public init(url: URL, suggestedFilename: String) {
        self.url = url
        self.suggestedFilename = suggestedFilename
    }
}

public enum ExportError: Error, Sendable, Equatable {
    case renderingFailed
    case encodingFailed
    case invalidFilename
    case writeFailed(String)
}

public enum ExportFilename {
    public static func sanitized(_ value: String, fallback: String = "Export") -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let parts = value.components(separatedBy: invalid)
        let collapsed = parts.joined(separator: "-")
            .split(whereSeparator: \ .isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? fallback : String(collapsed.prefix(96))
    }
}

public actor ExportFileWriter {
    private let fileManager: FileManager
    private let directory: URL

    public init(
        directory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func write(
        _ data: Data,
        filename: String,
        fileExtension: String
    ) throws -> ExportFile {
        let safeName = ExportFilename.sanitized(filename)
        guard !safeName.isEmpty else { throw ExportError.invalidFilename }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        do {
            try data.write(to: url, options: .atomic)
            return ExportFile(url: url, suggestedFilename: "\(safeName).\(fileExtension)")
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }

    public func remove(_ file: ExportFile) {
        try? fileManager.removeItem(at: file.url)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
public enum ViewImageExporter {
    public static func render<Content: View>(
        _ content: Content,
        size: CGSize,
        scale: CGFloat = 1,
        opaque: Bool = false,
        format: ExportImageFormat = .png
    ) throws -> Data {
        let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
        renderer.proposedSize = .init(size)
        renderer.scale = max(scale, 1)
        renderer.isOpaque = opaque

        guard let image = renderer.uiImage else { throw ExportError.renderingFailed }
        switch format {
        case .png:
            guard let data = image.pngData() else { throw ExportError.encodingFailed }
            return data
        case .jpeg(let quality):
            guard let data = image.jpegData(compressionQuality: min(max(quality, 0), 1)) else {
                throw ExportError.encodingFailed
            }
            return data
        }
    }
}
#endif
