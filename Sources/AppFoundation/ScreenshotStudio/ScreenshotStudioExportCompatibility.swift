#if canImport(SwiftUI) && canImport(UIKit)
  import Foundation
  import SwiftUI
  import UIKit

  struct ExportFile: Sendable, Equatable {
    let url: URL
    let suggestedFilename: String
  }

  struct ExportShareSheet: UIViewControllerRepresentable {
    private let files: [ExportFile]

    init(files: [ExportFile]) {
      self.files = files
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
      UIActivityViewController(
        activityItems: files.map(\.url),
        applicationActivities: nil
      )
    }

    func updateUIViewController(
      _ uiViewController: UIActivityViewController,
      context: Context
    ) {}
  }
#endif
