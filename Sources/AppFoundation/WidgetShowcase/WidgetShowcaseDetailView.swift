#if canImport(SwiftUI)
import SwiftUI

public struct WidgetShowcaseDetailView<Background: View>: View {
    private let item: WidgetShowcaseItem
    private let guide: WidgetInstallGuideConfiguration
    private let hasPro: Bool
    private let style: WidgetShowcaseStyle
    private let onRequestUpgrade: (() -> Void)?
    private let background: Background

    public init(
        item: WidgetShowcaseItem,
        guide: WidgetInstallGuideConfiguration,
        hasPro: Bool = true,
        style: WidgetShowcaseStyle = .standard,
        onRequestUpgrade: (() -> Void)? = nil,
        @ViewBuilder background: () -> Background
    ) {
        self.item = item
        self.guide = guide
        self.hasPro = hasPro
        self.style = style
        self.onRequestUpgrade = onRequestUpgrade
        self.background = background()
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = detailPreviewSize(availableWidth: Double(proxy.size.width - 36))

            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        preview(size: size)
                        descriptionCard

                        if item.access == .pro && !hasPro {
                            unlockCard
                        } else {
                            instructionSection
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(style.primaryTextColor)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(style.accentColor)
    }

    private func preview(size: WidgetShowcaseSize) -> some View {
        item.preview()
            .frame(width: size.width, height: size.height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: item.family.cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: item.family.cornerRadius,
                    style: .continuous
                )
                .strokeBorder(style.borderColor)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(item.title) widget preview")
    }

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.title2.bold())
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if item.access == .pro {
                    Label("PRO", systemImage: "crown.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(style.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(style.accentColor.opacity(0.13), in: Capsule())
                }
            }

            HStack(spacing: 8) {
                detailPill(item.family.title, systemImage: item.family.systemImage)
                ForEach(item.tags.prefix(3), id: \.self) { tag in
                    detailPill(tag, systemImage: "checkmark")
                }
            }
        }
        .padding(20)
        .background(style.surfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(style.borderColor)
        }
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Unlock this widget", systemImage: "lock.fill")
                .font(.title3.bold())
                .foregroundStyle(style.accentColor)

            Text("This design is registered as a Pro widget. Upgrade to use it and reveal its exact setup instructions.")
                .font(.subheadline)
                .foregroundStyle(style.secondaryTextColor)

            if let onRequestUpgrade {
                Button("View Pro options", action: onRequestUpgrade)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(style.surfaceColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(style.borderColor)
        }
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to add this widget")
                .font(.title3.bold())

            let steps = guide.steps(for: WidgetInstallGoal(descriptor: item.descriptor))
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                WidgetInstallStepRow(
                    number: index + 1,
                    step: step,
                    style: style
                )
            }

            if !guide.tip.isEmpty {
                Label(guide.tip, systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(style.secondaryTextColor)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func detailPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(style.secondaryTextColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(style.elevatedSurfaceColor, in: Capsule())
            .overlay { Capsule().strokeBorder(style.borderColor) }
    }

    private func detailPreviewSize(availableWidth: Double) -> WidgetShowcaseSize {
        switch item.family {
        case .small:
            let side = min(240, max(188, availableWidth * 0.68))
            return WidgetShowcaseSize(width: side, height: side)
        case .medium, .large:
            return item.family.previewSize(availableWidth: min(availableWidth, 390))
        }
    }
}

public struct WidgetInstallGuideView<Background: View>: View {
    private let goal: WidgetInstallGoal
    private let configuration: WidgetInstallGuideConfiguration
    private let style: WidgetShowcaseStyle
    private let background: Background

    public init(
        goal: WidgetInstallGoal = .general,
        configuration: WidgetInstallGuideConfiguration,
        style: WidgetShowcaseStyle = .standard,
        @ViewBuilder background: () -> Background
    ) {
        self.goal = goal
        self.configuration = configuration
        self.style = style
        self.background = background()
    }

    public var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    guideHeader

                    Text("Follow these steps")
                        .font(.title2.bold())

                    ForEach(Array(configuration.steps(for: goal).enumerated()), id: \.element.id) { index, step in
                        WidgetInstallStepRow(number: index + 1, step: step, style: style)
                    }

                    if !configuration.tip.isEmpty {
                        Label(configuration.tip, systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(style.secondaryTextColor)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(style.primaryTextColor)
        .navigationTitle(goal.isSpecific ? "Add This Widget" : "Add a Widget")
        .navigationBarTitleDisplayMode(.inline)
        .tint(style.accentColor)
    }

    private var guideHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(style.accentColor)
                    .frame(width: 52, height: 52)
                    .background(style.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                if let family = goal.family {
                    Text(family.title.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(style.accentColor)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(style.accentColor.opacity(0.13), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title ?? "\(configuration.appName) on your Home Screen")
                    .font(.title2.bold())
                Text(headerDescription)
                    .font(.subheadline)
                    .foregroundStyle(style.secondaryTextColor)
            }
        }
        .padding(20)
        .background(style.surfaceColor, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(style.borderColor)
        }
    }

    private var headerDescription: String {
        if let family = goal.family, let configurationName = goal.configurationName {
            return "Add a \(family.title.lowercased()) \(configuration.appName) widget, then select \(configurationName) in Edit Widget."
        }

        return "Add \(configuration.appName), choose the size that fits your Home Screen, then select your preferred design."
    }
}

public extension WidgetInstallGuideView where Background == Color {
    init(
        goal: WidgetInstallGoal = .general,
        configuration: WidgetInstallGuideConfiguration,
        style: WidgetShowcaseStyle = .standard
    ) {
        self.init(
            goal: goal,
            configuration: configuration,
            style: style,
            background: { style.backgroundColor }
        )
    }
}

private struct WidgetInstallStepRow: View {
    let number: Int
    let step: WidgetInstallStep
    let style: WidgetShowcaseStyle

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(style.accentColor.opacity(0.13))
                    .frame(width: 44, height: 44)

                Image(systemName: step.systemImage)
                    .font(.subheadline.bold())
                    .foregroundStyle(style.accentColor)
            }
            .overlay(alignment: .topTrailing) {
                Text(number.formatted())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 19, height: 19)
                    .background(.black.opacity(0.72), in: Circle())
                    .offset(x: 4, y: -4)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(step.title)
                    .font(.headline)
                Text(step.explanation)
                    .font(.subheadline)
                    .foregroundStyle(style.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(style.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style.borderColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(step.title). \(step.explanation)")
    }
}
#endif
