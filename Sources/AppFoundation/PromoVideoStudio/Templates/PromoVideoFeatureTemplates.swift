#if canImport(SwiftUI)
  import SwiftUI

  public struct HeroIntroPromoVideoScene<
    Background: View,
    Brand: View,
    Message: View,
    Visual: View
  >: View {
    private let context: PromoVideoSceneContext
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let visual: Visual

    public init(
      context: PromoVideoSceneContext,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder visual: () -> Visual
    ) {
      self.context = context
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.visual = visual()
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        let brandMotion = promoVideoEntrance(context: context, start: 0.02, end: 0.18, distance: 24)
        let messageMotion = promoVideoEntrance(context: context, start: 0.10, end: 0.34, distance: 42)
        let visualMotion = promoVideoEntrance(context: context, start: 0.24, end: 0.58, distance: 70)
        let drift = CGFloat(context.phase(from: 0.56, to: 1, curve: .smooth))
          * CGFloat(context.motionIntensity.scale) * -12

        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
            .opacity(brandMotion.opacity)
            .offset(y: brandMotion.offset)

          message
            .opacity(messageMotion.opacity)
            .offset(y: messageMotion.offset)

          visual
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .promoVideoTemplateSurface(
              cornerRadius: metrics.cornerRadius,
              shadowRadius: metrics.shadowRadius
            )
            .opacity(visualMotion.opacity)
            .scaleEffect(visualMotion.scale)
            .offset(y: visualMotion.offset + drift)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }

  public struct DeviceRevealPromoVideoScene<
    Background: View,
    Brand: View,
    Message: View,
    Device: View,
    Footer: View
  >: View {
    private let context: PromoVideoSceneContext
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let device: Device
    private let footer: Footer

    public init(
      context: PromoVideoSceneContext,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder device: () -> Device,
      @ViewBuilder footer: () -> Footer
    ) {
      self.context = context
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.device = device()
      self.footer = footer()
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        let headerMotion = promoVideoEntrance(context: context, start: 0.03, end: 0.24, distance: 30)
        let devicePhase = context.phase(from: 0.16, to: 0.62, curve: .spring)
        let footerPhase = context.phase(from: 0.48, to: 0.72, curve: .easeOut)
        let intensity = context.motionIntensity.scale
        let rotation = (1 - devicePhase) * -5 * intensity
        let scale = 0.78 + devicePhase * 0.22
        let drift = context.phase(from: 0.62, to: 1, curve: .smooth) * -9 * intensity

        VStack(alignment: .leading, spacing: metrics.minorSpacing) {
          brand
            .opacity(headerMotion.opacity)
            .offset(y: headerMotion.offset)

          message
            .opacity(headerMotion.opacity)
            .offset(y: headerMotion.offset)
            .padding(.bottom, metrics.minorSpacing)

          device
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .promoVideoTemplateSurface(
              cornerRadius: metrics.cornerRadius,
              shadowRadius: metrics.shadowRadius * 1.1,
              shadowOpacity: 0.30
            )
            .scaleEffect(CGFloat(scale))
            .rotationEffect(.degrees(rotation))
            .offset(y: CGFloat((1 - devicePhase) * 110 * intensity + drift))
            .opacity(devicePhase)

          footer
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(footerPhase)
            .offset(y: CGFloat((1 - footerPhase) * 22))
            .padding(.top, metrics.minorSpacing)
        }
        .padding(.horizontal, metrics.horizontalMargin)
        .padding(.top, metrics.topMargin)
        .padding(.bottom, metrics.bottomMargin)
      }
    }
  }

  public struct FeatureFocusPromoVideoScene<
    Background: View,
    Brand: View,
    Message: View,
    Visual: View,
    Callout: View
  >: View {
    private let context: PromoVideoSceneContext
    private let background: Background
    private let brand: Brand
    private let message: Message
    private let visual: Visual
    private let callout: Callout

    public init(
      context: PromoVideoSceneContext,
      @ViewBuilder background: () -> Background,
      @ViewBuilder brand: () -> Brand,
      @ViewBuilder message: () -> Message,
      @ViewBuilder visual: () -> Visual,
      @ViewBuilder callout: () -> Callout
    ) {
      self.context = context
      self.background = background()
      self.brand = brand()
      self.message = message()
      self.visual = visual()
      self.callout = callout()
    }

    public var body: some View {
      PromoVideoTemplateCanvas(background: background) { metrics in
        let header = promoVideoEntrance(context: context, start: 0.02, end: 0.26, distance: 32)
        let visualPhase = context.phase(from: 0.16, to: 0.54, curve: .easeOut)
        let calloutPhase = context.phase(from: 0.48, to: 0.76, curve: .spring)
        let intensity = context.motionIntensity.scale
        let pan = context.phase(from: 0.56, to: 1, curve: .smooth) * -18 * intensity

        VStack(alignment: .leading, spacing: metrics.majorSpacing) {
          brand
            .opacity(header.opacity)
            .offset(y: header.offset)

          message
            .opacity(header.opacity)
            .offset(y: header.offset)

          GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
              visual
                .frame(width: proxy.size.width * 0.92, height: proxy.size.height * 0.92)
                .promoVideoTemplateSurface(
                  cornerRadius: metrics.cornerRadius,
                  shadowRadius: metrics.shadowRadius
                )
                .scaleEffect(CGFloat(0.90 + visualPhase * 0.10))
                .offset(
                  x: CGFloat((1 - visualPhase) * 44 * intensity),
                  y: CGFloat((1 - visualPhase) * 62 * intensity + pan)
                )
                .opacity(visualPhase)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

              callout
                .promoVideoTemplateSurface(
                  cornerRadius: metrics.smallCornerRadius,
                  shadowRadius: metrics.shadowRadius * 0.65,
                  shadowOpacity: 0.20
                )
                .scaleEffect(CGFloat(0.82 + calloutPhase * 0.18))
                .offset(
                  x: CGFloat((1 - calloutPhase) * 28),
                  y: CGFloat((1 - calloutPhase) * 34)
                )
                .opacity(calloutPhase)
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
#endif
