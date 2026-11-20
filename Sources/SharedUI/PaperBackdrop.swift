import SwiftUI

/// Kraft-paper desk with a few faint hand-drawn food marks. Decorative only:
/// the Canvas is non-interactive and hidden from VoiceOver.
struct PaperBackdrop: View {
    var body: some View {
        ZStack {
            Zine.kraft.ignoresSafeArea()
            Canvas { context, size in
                let marks: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.12, 0.10, 36), (0.84, 0.18, 28), (0.18, 0.52, 30),
                    (0.78, 0.62, 34), (0.10, 0.86, 24), (0.86, 0.90, 26)
                ]
                for (x, y, radius) in marks {
                    let center = CGPoint(x: size.width * x, y: size.height * y)
                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(200),
                        endAngle: .degrees(340),
                        clockwise: false
                    )
                    context.stroke(path, with: .color(Zine.ink.opacity(0.06)), lineWidth: 1.2)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct PaperCard<Content: View>: View {
    var padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Zine.cardRadius)
                    .fill(Zine.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Zine.cardRadius)
                    .stroke(Zine.border, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: Zine.cardRadius)
                    .fill(Zine.shadow)
                    .offset(x: 3, y: 3)
            )
    }
}

struct SectionHeading: View {
    var index: String?
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let index {
                Text(index)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Zine.red)
            }
            Text(title)
                .font(Zine.sectionFont)
                .foregroundStyle(Zine.ink)
                .accessibilityAddTraits(.isHeader)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InkButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(primary ? Zine.onRed : Zine.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: Zine.buttonRadius)
                    .fill(primary ? Zine.red : Zine.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Zine.buttonRadius)
                    .stroke(Zine.ink, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: Zine.buttonRadius)
                    .fill(Zine.ink.opacity(0.18))
                    .offset(x: 2, y: 2)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Zine.red)
            .underline()
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
