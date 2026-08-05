import AppFoundation
import SwiftUI

struct DemoOnboardingPageView: View {
    let page: FoundationOnboardingPage
    let context: FoundationOnboardingPageContext

    @ViewBuilder
    var body: some View {
        switch page.id {
        case "foundation":
            foundationPage
        case "infrastructure":
            infrastructurePage
        default:
            FoundationOnboardingStandardPage(page: page, context: context)
        }
    }

    private var foundationPage: some View {
        VStack(spacing: 26) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(context.theme.primary.opacity(0.12))
                    .frame(width: 190, height: 150)
                    .rotationEffect(.degrees(-9))

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(context.theme.secondary.opacity(0.14))
                    .frame(width: 190, height: 150)
                    .rotationEffect(.degrees(8))

                Image(systemName: page.systemImage)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(context.theme.primary)
            }
            .scaleEffect(context.isSelected ? 1 : 0.88)
            .opacity(context.isSelected ? 1 : 0.45)

            onboardingCopy
        }
        .animation(.bouncy, value: context.isSelected)
    }

    private var infrastructurePage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    capabilityCard("square.and.arrow.up.fill", title: "Export")
                    capabilityCard("externaldrive.fill", title: "Backup")
                }
                HStack(spacing: 12) {
                    capabilityCard("widget.small", title: "Widgets")
                    capabilityCard("bell.badge.fill", title: "Reminders")
                }
            }
            .scaleEffect(context.isSelected ? 1 : 0.94)
            .opacity(context.isSelected ? 1 : 0.55)

            onboardingCopy
        }
        .animation(.smooth, value: context.isSelected)
    }

    private var onboardingCopy: some View {
        VStack(spacing: 10) {
            Text(page.eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(context.theme.primary)

            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(context.primaryForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.message)
                .font(.body)
                .foregroundStyle(context.secondaryForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func capabilityCard(_ systemImage: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(context.theme.primary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(context.primaryForeground)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(context.theme.primary.opacity(0.14))
        }
    }
}
