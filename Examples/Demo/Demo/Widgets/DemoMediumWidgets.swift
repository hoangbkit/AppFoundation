import AppFoundation
import SwiftUI

struct DemoScreenshotStudioMedium: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    DemoWidgetHeader(
                        title: "Screenshot Studio",
                        systemImage: "photo.stack.fill",
                        accent: theme.accentColor,
                        trailing: "5 SCENES"
                    )

                    Text("App Store set")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                    Text("Responsive native layouts")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        DemoFeaturePill(title: "Ready", systemImage: "checkmark", accent: theme.accentColor)
                        DemoFeaturePill(title: "6.9\"", systemImage: "iphone", accent: theme.accentColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .bottom, spacing: 6) {
                    screenshotCard(height: 86, index: 1)
                    screenshotCard(height: 104, index: 2)
                    screenshotCard(height: 78, index: 3)
                }
                .frame(width: 132)
            }
            .padding(15)
        }
    }

    private func screenshotCard(height: CGFloat, index: Int) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(.white.opacity(index == 2 ? 0.16 : 0.09))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(index == 2 ? theme.accentColor : .white.opacity(0.3))
                    .frame(width: 20, height: 3)
                    .padding(.top, 7)
            }
            .overlay {
                VStack(spacing: 5) {
                    Circle()
                        .fill(theme.accentColor.opacity(index == 2 ? 0.9 : 0.45))
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.62))
                        .frame(width: 25, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.25))
                        .frame(width: 18, height: 3)
                }
            }
            .frame(width: 38, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            }
    }
}

struct DemoPromoStudioMedium: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 12) {
                DemoWidgetHeader(
                    title: "Promo Studio",
                    systemImage: "play.rectangle.fill",
                    accent: theme.accentColor,
                    trailing: "00:12"
                )

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A story, not a slideshow")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .lineLimit(2)
                        Text("7 animated scenes")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.white.opacity(0.1))
                            .frame(width: 72, height: 94)
                        Image(systemName: "play.fill")
                            .font(.title2.bold())
                            .foregroundStyle(theme.accentColor)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.34), in: Circle())
                    }
                }

                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        Capsule()
                            .fill(index < 5 ? theme.accentColor : .white.opacity(0.16))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 5)

                HStack {
                    DemoStatusDot(title: "9:16", isActive: true, accent: theme.accentColor)
                    DemoStatusDot(title: "1:1", isActive: true, accent: theme.accentColor)
                    DemoStatusDot(title: "16:9", isActive: true, accent: theme.accentColor)
                    Spacer()
                    Text("Responsive")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(15)
        }
    }
}

struct DemoNotificationCenterMedium: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    DemoWidgetHeader(
                        title: "Notifications",
                        systemImage: "bell.badge.fill",
                        accent: theme.accentColor,
                        trailing: "ALLOWED"
                    )

                    Text("3 scheduled")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                    Text("Next request in 42 min")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))

                    Spacer(minLength: 0)

                    DemoFeaturePill(title: "Authorized", systemImage: "checkmark.shield.fill", accent: theme.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 7) {
                    notificationRow("Launch review", time: "16:30", active: true)
                    notificationRow("Backup check", time: "18:00", active: true)
                    notificationRow("Weekly report", time: "Fri", active: false)
                }
                .frame(width: 150)
            }
            .padding(15)
        }
    }

    private func notificationRow(_ title: String, time: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(active ? theme.accentColor : .white.opacity(0.18))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(time)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
