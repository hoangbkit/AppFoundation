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

public struct ExportRenderRequest: Sendable, Equatable {
    public let width: Double
    public let height: Double
    public let scale: Double
    public let maximumPixelCount: Int

    public init(
        width: Double,
        height: Double,
        scale: Double = 1,
        maximumPixelCount: Int = 40_000_000
    ) {
        self.width = width
        self.height = height
        self.scale = scale
        self.maximumPixelCount = maximumPixelCount
    }

    public var pixelCount: Int {
        guard width > 0, height > 0, scale > 0 else { return 0 }
        let value = width * scale * height * scale
        return value >= Double(Int.max) ? Int.max : Int(value.rounded(.up))
    }

    public func validate() throws {
        guard width > 0, height > 0, scale > 0 else { throw ExportError.invalidSize }
        guard maximumPixelCount > 0 else { throw ExportError.invalidPixelLimit }
        guard pixelCount <= maximumPixelCount else {
            throw ExportError.exceedsPixelLimit(requested: pixelCount, maximum: maximumPixelCount)
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
    case invalidFileExtension
    case invalidSize
    case invalidPixelLimit
    case exceedsPixelLimit(requested: Int, maximum: Int)
    case writeFailed(String)
}

public enum ExportFilename {
    public static func sanitized(_ value: String, fallback: String = "Export") -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let parts = value.components(separatedBy: invalid)
        let collapsed = parts.joined(separator: "-")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? fallback : String(collapsed.prefix(96))
    }

    public static func sanitizedExtension(_ value: String) -> String? {
        let candidate = value.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard !candidate.isEmpty,
              candidate.count <= 12,
              candidate.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) })
        else { return nil }
        return candidate.lowercased()
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
        guard let safeExtension = ExportFilename.sanitizedExtension(fileExtension) else {
            throw ExportError.invalidFileExtension
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString)")
            .appendingPathExtension(safeExtension)
        do {
            try data.write(to: url, options: .atomic)
            return ExportFile(url: url, suggestedFilename: "\(safeName).\(safeExtension)")
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
        cornerRadius: CGFloat = 0,
        maximumPixelCount: Int = 40_000_000,
        format: ExportImageFormat = .png
    ) throws -> Data {
        let request = ExportRenderRequest(
            width: Double(size.width),
            height: Double(size.height),
            scale: Double(scale),
            maximumPixelCount: maximumPixelCount
        )
        try request.validate()

        let renderedContent = content
            .frame(width: size.width, height: size.height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: max(cornerRadius, 0),
                    style: .continuous
                )
            )

        let renderer = ImageRenderer(content: renderedContent)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
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

public struct ExportShareSheet: UIViewControllerRepresentable {
    private let files: [ExportFile]
    private let completion: ((Bool) -> Void)?

    public init(files: [ExportFile], completion: ((Bool) -> Void)? = nil) {
        self.files = files
        self.completion = completion
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: files.map(\.url),
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        return controller
    }

    public func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
#endif
