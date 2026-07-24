import AppFoundationPromoVideoStudio
import AppFoundationScreenshotStudio
import SwiftUI

@MainActor
struct MacHomeView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Mac Studios") {
          NavigationLink {
            MacScreenshotStudioDemoView()
          } label: {
            MacFeatureRow(
              title: "Screenshot Studio",
              subtitle: "Design, preview, batch-render, and export exact Mac App Store PNGs.",
              systemImage: "photo.on.rectangle.angled"
            )
          }

          NavigationLink {
            MacPromoVideoStudioDemoView()
          } label: {
            MacFeatureRow(
              title: "Promo Video Studio",
              subtitle: "Preview deterministic SwiftUI stories and export silent H.264 MP4 video.",
              systemImage: "film.stack"
            )
          }
        }

        Section("Scope") {
          LabeledContent("Platform", value: "macOS 15+")
          LabeledContent("Included", value: "Mac-supported AppFoundation products only")
        }
      }
      .navigationTitle("AppFoundation for Mac")
    }
  }
}

private struct MacFeatureRow: View {
  let title: String
  let subtitle: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.title2)
        .frame(width: 42, height: 42)
        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 8)
  }
}
