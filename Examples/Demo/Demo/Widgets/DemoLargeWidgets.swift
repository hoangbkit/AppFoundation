import AppFoundation
import SwiftUI

struct DemoFoundationDashboardLarge: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                DemoWidgetHeader(
                    title: "AppFoundation",
                    systemImage: "square.stack.3d.up.fill",
                    accent: theme.accentColor,
                    trailing: "HEALTHY"
                )

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Shared infrastructure")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                        Text("Everything ready for the next app")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                    Spacer()
                    Text("9/9")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(theme.accentColor)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    dashboardTile("Commerce", value: "Pro", systemImage: "cart.fill", progress: 0.86)
                    dashboardTile("Themes", value: "6", systemImage: "paintpalette.fill", progress: 1)
                    dashboardTile("Backup", value: "Ready", systemImage: "externaldrive.fill", progress: 1)
                    dashboardTile("Alerts", value: "3", systemImage: "bell.fill", progress: 0.68)
                }

                DemoGlassPanel {
                    VStack(spacing: 8) {
                        DemoMetricRow(title: "Package tests", value: "100%", progress: 1, accent: theme.accentColor)
                        DemoMetricRow(title: "Snapshot freshness", value: "94%", progress: 0.94, accent: theme.accentColor)
                    }
                }

                HStack {
                    DemoFeaturePill(title: "Swift 6", systemImage: "swift", accent: theme.accentColor)
                    DemoFeaturePill(title: "iOS 26", systemImage: "iphone", accent: theme.accentColor)
                    Spacer()
                    Text("Updated now")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.54))
                }
            }
            .padding(16)
        }
    }

    private func dashboardTile(
        _ title: String,
        value: String,
        systemImage: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(theme.accentColor)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(theme.accentColor).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct DemoContentPipelineLarge: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 15) {
                DemoWidgetHeader(
                    title: "Content Pipeline",
                    systemImage: "film.fill",
                    accent: theme.accentColor,
                    trailing: "EXPORTING"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("From native views to launch-ready media")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                    Text("Registered content stays responsive across every output.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                }

                pipelineRow(
                    number: "01",
                    title: "Screenshot Studio",
                    subtitle: "5 scenes • 6.9-inch set",
                    systemImage: "photo.stack.fill",
                    progress: 1
                )
                pipelineConnector
                pipelineRow(
                    number: "02",
                    title: "Promo Studio",
                    subtitle: "7 scenes • 4 aspect ratios",
                    systemImage: "play.rectangle.fill",
                    progress: 0.78
                )
                pipelineConnector
                pipelineRow(
                    number: "03",
                    title: "Export Kit",
                    subtitle: "Optimizing final assets",
                    systemImage: "square.and.arrow.up.fill",
                    progress: 0.46
                )

                HStack(spacing: 6) {
                    DemoFeaturePill(title: "9:16", systemImage: "rectangle.portrait", accent: theme.accentColor)
                    DemoFeaturePill(title: "1:1", systemImage: "square", accent: theme.accentColor)
                    DemoFeaturePill(title: "16:9", systemImage: "rectangle", accent: theme.accentColor)
                }
            }
            .padding(16)
        }
    }

    private func pipelineRow(
        number: String,
        title: String,
        subtitle: String,
        systemImage: String,
        progress: Double
    ) -> some View {
        HStack(spacing: 11) {
            Text(number)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(theme.accentColor)
                .frame(width: 28, height: 28)
                .background(theme.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Image(systemName: systemImage)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer(minLength: 8)

            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 30, height: 30)
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var pipelineConnector: some View {
        Rectangle()
            .fill(theme.accentColor.opacity(0.38))
            .frame(width: 2, height: 7)
            .padding(.leading, 23)
            .padding(.vertical, -4)
    }
}

struct DemoReleaseReadinessLarge: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                DemoWidgetHeader(
                    title: "Release Readiness",
                    systemImage: "checkmark.seal.fill",
                    accent: theme.accentColor,
                    trailing: "READY"
                )

                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.1), lineWidth: 11)
                        Circle()
                            .trim(from: 0, to: 0.96)
                            .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("96")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                            Text("SCORE")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .frame(width: 112, height: 112)

                    VStack(alignment: .leading, spacing: 9) {
                        readinessRow("Package tests", value: "Passing", active: true)
                        readinessRow("Backup archive", value: "Valid", active: true)
                        readinessRow("Shared snapshot", value: "Fresh", active: true)
                        readinessRow("Notifications", value: "Allowed", active: true)
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider().overlay(.white.opacity(0.12))

                HStack(spacing: 8) {
                    readinessMetric("42", label: "Tests", icon: "checkmark.circle.fill")
                    readinessMetric("6", label: "Themes", icon: "paintpalette.fill")
                    readinessMetric("9", label: "Widgets", icon: "square.grid.2x2.fill")
                }

                DemoGlassPanel {
                    HStack {
                        DemoStatusDot(title: "Production safeguards enabled", isActive: true, accent: theme.accentColor)
                        Spacer()
                        Text("v0.1.4+")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(theme.accentColor)
                    }
                }
            }
            .padding(16)
        }
    }

    private func readinessRow(_ title: String, value: String, active: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .font(.caption.bold())
                .foregroundStyle(active ? theme.accentColor : .white.opacity(0.24))
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
            Spacer()
            Text(value)
                .font(.system(size: 8, weight: .bold, design: .rounded))
        }
    }

    private func readinessMetric(_ value: String, label: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(theme.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Text(label)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
