#if os(iOS) && canImport(SwiftUI)
  import SwiftUI

  public struct LayeredScreensPromoVideoScene<
    Background: View,
    Brand: View,
    Message: View,
    Primary: View,
    Secondary: View,
    Tertiary: View
  >: View {
    private let context: PromoVideoSceneContext
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let primary: Primary
    private let secondary: Secondary
    private let tertiary: Tertiary

    public init(
      context: PromoVideoSceneContext,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder primary: () -> Primary,
      @ViewBuilder secondary: () -> Secondary,
      @ViewBuilder tertiary: () -> Tertiary
    ) {
      self.context = context
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.primary = primary()
      self.secondary = secondary()
      self.tertiary = tertiary()
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        let header = promoVideoEntrance(context: context, start: 0.02, end: 0.24, distance: 30)
        let tertiaryPhase = context.phase(from: 0.16, to: 0.45, curve: .easeOut)
        let secondaryPhase = context.phase(from: 0.25, to: 0.56, curve: .easeOut)
        let primaryPhase = context.phase(from: 0.34, to: 0.67, curve: .spring)
        let settle = context.phase(from: 0.66, to: 1, curve: .smooth)
        let intensity = context.motionIntensity.scale

        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
            .opacity(header.opacity)
            .offset(y: header.offset)

          message
            .opacity(header.opacity)
            .offset(y: header.offset)

          GeometryReader { proxy in
            ZStack {
              tertiary
                .frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.78)
                .promoVideoTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.shadowRadius * 0.72,
                  shadowOpacity: 0.18
                )
                .rotationEffect(.degrees(7 * tertiaryPhase * intensity))
                .offset(
                  x: CGFloat(52 * tertiaryPhase * intensity),
                  y: CGFloat((1 - tertiaryPhase) * 90 * intensity - settle * 8)
                )
                .opacity(tertiaryPhase)

              secondary
                .frame(width: proxy.size.width * 0.76, height: proxy.size.height * 0.84)
                .promoVideoTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.shadowRadius * 0.88,
                  shadowOpacity: 0.22
                )
                .rotationEffect(.degrees(-5 * secondaryPhase * intensity))
                .offset(
                  x: CGFloat(-44 * secondaryPhase * intensity),
                  y: CGFloat((1 - secondaryPhase) * 100 * intensity - settle * 5)
                )
                .opacity(secondaryPhase)

              primary
                .frame(width: proxy.size.width * 0.80, height: proxy.size.height * 0.88)
                .promoVideoTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.shadowRadius * 1.08,
                  shadowOpacity: 0.29
                )
                .scaleEffect(CGFloat(0.84 + primaryPhase * 0.16))
                .offset(y: CGFloat((1 - primaryPhase) * 120 * intensity - settle * 12))
                .opacity(primaryPhase)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }

  public struct AppFlowPromoVideoScene<
    Background: View,
    Brand: View,
    Message: View,
    First: View,
    Second: View,
    Third: View
  >: View {
    private let context: PromoVideoSceneContext
    private let stepTitles: [String]
    private let accent: Color
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let first: First
    private let second: Second
    private let third: Third

    public init(
      context: PromoVideoSceneContext,
      stepTitles: [String],
      accent: Color = .accentColor,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder first: () -> First,
      @ViewBuilder second: () -> Second,
      @ViewBuilder third: () -> Third
    ) {
      self.context = context
      self.stepTitles = Array((stepTitles + ["First", "Second", "Third"]).prefix(3))
      self.accent = accent
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.first = first()
      self.second = second()
      self.third = third()
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        let header = promoVideoEntrance(context: context, start: 0.01, end: 0.20, distance: 26)

        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
            .opacity(header.opacity)
            .offset(y: header.offset)

          message
            .opacity(header.opacity)
            .offset(y: header.offset)

          GeometryReader { proxy in
            ZStack {
              flowStep(
                index: 0,
                content: first,
                size: proxy.size,
                metrics: metrics
              )
              flowStep(
                index: 1,
                content: second,
                size: proxy.size,
                metrics: metrics
              )
              flowStep(
                index: 2,
                content: third,
                size: proxy.size,
                metrics: metrics
              )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }

          stepIndicator
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }

    private func flowStep<Content: View>(
      index: Int,
      content: Content,
      size: CGSize,
      metrics: PromoVideoTemplateMetrics
    ) -> some View {
      let start = 0.18 + Double(index) * 0.22
      let middle = start + 0.14
      let end = min(start + 0.38, 0.98)
      let enter = context.phase(from: start, to: middle, curve: .easeOut)
      let leave = context.phase(from: end - 0.12, to: end, curve: .easeIn)
      let visibility = min(enter, 1 - leave)
      let intensity = context.motionIntensity.scale
      let enterOffset = (1 - enter) * 96 * intensity
      let leaveOffset = leave * -54 * intensity

      return content
        .frame(width: size.width * 0.88, height: size.height * 0.90)
        .promoVideoTemplateSurface(
          cornerRadius: metrics.cornerRadius,
          shadowRadius: metrics.shadowRadius,
          shadowOpacity: 0.27
        )
        .scaleEffect(CGFloat(0.94 + visibility * 0.06))
        .offset(x: CGFloat(enterOffset + leaveOffset))
        .opacity(visibility)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stepIndicator: some View {
      HStack(spacing: 8) {
        ForEach(0..<3, id: \.self) { index in
          let active = activeStep == index
          HStack(spacing: 6) {
            Text("\(index + 1)")
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .frame(width: 22, height: 22)
              .background(active ? accent : Color.white.opacity(0.12), in: Circle())

            Text(stepTitles[index])
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .lineLimit(1)
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(active ? accent.opacity(0.30) : Color.white.opacity(0.06), in: Capsule())
          .overlay {
            Capsule()
              .strokeBorder(active ? accent.opacity(0.55) : Color.white.opacity(0.08))
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeStep: Int {
      if context.progress < 0.40 { return 0 }
      if context.progress < 0.64 { return 1 }
      return 2
    }
  }

  public struct OutroCallToActionPromoVideoScene<
    Background: View,
    Icon: View,
    Message: View,
    CallToAction: View,
    Footer: View
  >: View {
    private let context: PromoVideoSceneContext
    private let background: Background
    private let icon: Icon
    private let message: Message
    private let callToAction: CallToAction
    private let footer: Footer

    public init(
      context: PromoVideoSceneContext,
      @ViewBuilder background: () -> Background,
      @ViewBuilder icon: () -> Icon,
      @ViewBuilder message: () -> Message,
      @ViewBuilder callToAction: () -> CallToAction,
      @ViewBuilder footer: () -> Footer
    ) {
      self.context = context
      self.background = background()
      self.icon = icon()
      self.message = message()
      self.callToAction = callToAction()
      self.footer = footer()
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        let iconPhase = context.phase(from: 0.02, to: 0.30, curve: .spring)
        let messagePhase = context.phase(from: 0.16, to: 0.46, curve: .easeOut)
        let ctaPhase = context.phase(from: 0.38, to: 0.66, curve: .spring)
        let footerPhase = context.phase(from: 0.56, to: 0.78, curve: .easeOut)
        let pulsePhase = context.phase(from: 0.70, to: 1, curve: .smooth)
        let pulse = 1 + sin(pulsePhase * .pi * 2) * 0.025 * context.motionIntensity.scale

        VStack(spacing: metrics.majorSpacing) {
          Spacer(minLength: 0)

          icon
            .frame(width: metrics.size.width * 0.27, height: metrics.size.width * 0.27)
            .promoVideoTemplateSurface(
              cornerRadius: metrics.cornerRadius,
              shadowRadius: metrics.shadowRadius * 1.1,
              shadowOpacity: 0.30
            )
            .scaleEffect(CGFloat((0.72 + iconPhase * 0.28) * pulse))
            .opacity(iconPhase)

          message
            .opacity(messagePhase)
            .offset(y: CGFloat((1 - messagePhase) * 34))

          callToAction
            .scaleEffect(CGFloat(0.84 + ctaPhase * 0.16))
            .opacity(ctaPhase)

          footer
            .opacity(footerPhase)
            .offset(y: CGFloat((1 - footerPhase) * 18))

          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.vertical, metrics.topMargin)
      }
    }
  }

  public struct ContinuousCanvasPromoVideoScene<Background: View, Content: View>: View {
    private let context: PromoVideoSceneContext
    private let background: Background
    private let content: (PromoVideoSceneContext) -> Content

    public init(
      context: PromoVideoSceneContext,
      @ViewBuilder background: () -> Background,
      @ViewBuilder content: @escaping (PromoVideoSceneContext) -> Content
    ) {
      self.context = context
      self.background = background()
      self.content = content
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        content(context)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.horizontal, metrics.horizontalMargin)
          .padding(.vertical, metrics.topMargin)
      }
    }
  }
#endif
