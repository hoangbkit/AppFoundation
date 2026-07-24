import SwiftUI

@MainActor
struct MacHomeView: View {
  @Environment(\.openWindow) private var openWindow

  private let columns = [
    GridItem(.flexible(), spacing: 20),
    GridItem(.flexible(), spacing: 20),
  ]

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.accentColor.opacity(0.10), .clear, Color.accentColor.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          hero

          LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            MacStudioCard(
              title: "Screenshot Studio",
              subtitle: "Create App Store screenshots from registered SwiftUI compositions.",
              systemImage: "photo.on.rectangle.angled",
              features: [
                "Live canvas and full-set preview",
                "Contextual screenshot and campaign controls",
                "Exact opaque PNG batch export",
              ],
              actionTitle: "Open Screenshot Studio"
            ) {
              openWindow(id: MacDemoWindowID.screenshotStudio)
            }

            MacStudioCard(
              title: "Promo Video Studio",
              subtitle: "Build deterministic promotional stories with native timeline tools.",
              systemImage: "film.stack",
              features: [
                "Multi-video and scene-based workflow",
                "Timeline playback, scrubbing, and safe areas",
                "Frame-accurate H.264 MP4 export",
              ],
              actionTitle: "Open Promo Video Studio"
            ) {
              openWindow(id: MacDemoWindowID.promoVideoStudio)
            }
          }

          navigationHint
        }
        .frame(maxWidth: 1120, alignment: .leading)
        .padding(32)
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button {
          openWindow(id: MacDemoWindowID.screenshotStudio)
        } label: {
          Label("Screenshot Studio", systemImage: "photo")
        }
        .help("Open Screenshot Studio (⌘1)")

        Button {
          openWindow(id: MacDemoWindowID.promoVideoStudio)
        } label: {
          Label("Promo Video Studio", systemImage: "film")
        }
        .help("Open Promo Video Studio (⌘2)")
      }
    }
  }

  private var hero: some View {
    HStack(alignment: .center, spacing: 22) {
      Image(systemName: "swift")
        .font(.system(size: 40, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 76, height: 76)
        .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 20))

      VStack(alignment: .leading, spacing: 7) {
        Text("AppFoundation for Mac")
          .font(.largeTitle.bold())
        Text("Developer media tools built with native SwiftUI workflows.")
          .font(.title3)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 24)

      VStack(alignment: .trailing, spacing: 8) {
        Label("macOS 15+", systemImage: "apple.logo")
          .font(.headline)
        Text("Screenshot and promo-video production")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding(26)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.primary.opacity(0.08))
    }
  }

  private var navigationHint: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "macwindow.on.rectangle")
        .font(.title2)
        .foregroundStyle(.tint)
        .frame(width: 34)

      VStack(alignment: .leading, spacing: 5) {
        Text("Designed for Mac window workflows")
          .font(.headline)
        Text(
          "Each Studio opens in its own reusable window, so this dashboard stays available. Use ⌘0 for Home, ⌘1 for Screenshot Studio, or ⌘2 for Promo Video Studio."
        )
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
  }
}

private struct MacStudioCard: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let features: [String]
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: systemImage)
          .font(.title2)
          .foregroundStyle(.tint)
          .frame(width: 48, height: 48)
          .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

        VStack(alignment: .leading, spacing: 5) {
          Text(title)
            .font(.title2.bold())
          Text(subtitle)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Label("Native macOS support", systemImage: "checkmark.circle.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.green)

      VStack(alignment: .leading, spacing: 10) {
        ForEach(features, id: \.self) { feature in
          Label(feature, systemImage: "checkmark")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 4)

      Button(actionTitle, action: action)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    .padding(24)
    .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(.primary.opacity(0.08))
    }
  }
}
