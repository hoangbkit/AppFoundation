import AppFoundation
import SwiftUI

struct DemoCommercePulseSmall: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 11) {
                DemoWidgetHeader(
                    title: "Commerce",
                    systemImage: "cart.fill",
                    accent: theme.accentColor,
                    trailing: "LIVE"
                )

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: 0.82)
                        .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Image(systemName: "crown.fill")
                            .font(.caption.bold())
                            .foregroundStyle(theme.accentColor)
                        Text("PRO")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                    }
                }
                .frame(width: 70, height: 70)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                HStack {
                    DemoStatusDot(title: "Verified", isActive: true, accent: theme.accentColor)
                    Spacer()
                    Text("StoreKit 2")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(14)
        }
    }
}

struct DemoThemeOrbitSmall: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                DemoWidgetHeader(
                    title: "Themes",
                    systemImage: "paintpalette.fill",
                    accent: theme.accentColor,
                    trailing: "6"
                )

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 88, height: 88)
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(.headline.bold())
                        }

                    orbitDot(angle: -55, color: .white)
                    orbitDot(angle: 15, color: theme.accentColor.opacity(0.7))
                    orbitDot(angle: 92, color: .white.opacity(0.55))
                    orbitDot(angle: 168, color: theme.accentColor)
                    orbitDot(angle: 235, color: .white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                Text("Timed Pro preview")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
            }
            .padding(14)
        }
    }

    private func orbitDot(angle: Double, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .offset(y: -44)
            .rotationEffect(.degrees(angle))
    }
}

struct DemoBackupHealthSmall: View {
    let theme: AppTheme

    var body: some View {
        DemoWidgetCanvas(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                DemoWidgetHeader(
                    title: "Backup",
                    systemImage: "externaldrive.fill.badge.checkmark",
                    accent: theme.accentColor,
                    trailing: "NOW"
                )

                Spacer(minLength: 0)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, theme.accentColor)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Recovery ready")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Archive validated")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                DemoMetricRow(title: "Integrity", value: "100%", progress: 1, accent: theme.accentColor)
            }
            .padding(14)
        }
    }
}
