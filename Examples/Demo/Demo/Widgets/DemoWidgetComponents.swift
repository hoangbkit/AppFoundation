import AppFoundation
import SwiftUI

struct DemoWidgetCanvas<Content: View>: View {
    let theme: AppTheme
    let content: Content

    init(theme: AppTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.86)
            theme.gradient.opacity(0.72)

            RadialGradient(
                colors: [theme.accentColor.opacity(0.48), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 320
            )

            LinearGradient(
                colors: [.white.opacity(0.11), .clear, .black.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            content
                .foregroundStyle(.white)
        }
    }
}

struct DemoWidgetHeader: View {
    let title: String
    let systemImage: String
    let accent: Color
    var trailing: String?

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.bold())
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)

            Spacer(minLength: 4)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }
}

struct DemoFeaturePill: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(accent.opacity(0.18), in: Capsule())
            .overlay { Capsule().strokeBorder(accent.opacity(0.32)) }
    }
}

struct DemoMetricRow: View {
    let title: String
    let value: String
    let progress: Double
    let accent: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(value)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 5)
        }
    }
}

struct DemoStatusDot: View {
    let title: String
    let isActive: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? accent : .white.opacity(0.24))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
        }
    }
}

struct DemoGlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            }
    }
}
