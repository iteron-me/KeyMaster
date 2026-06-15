import SwiftUI

enum LiquidGlassStyle {
    static let windowRadius: CGFloat = 28
    static let panelRadius: CGFloat = 22
    static let controlRadius: CGFloat = 18
    static let keyRadius: CGFloat = 10
}

struct LiquidGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let isElevated: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.86))
                    .allowsHitTesting(false)

                shape
                    .fill(tint)
                    .allowsHitTesting(false)
            }
            .overlay(highlight(for: shape))
            .shadow(
                color: .black.opacity(isElevated ? 0.10 : 0.04),
                radius: isElevated ? 16 : 8,
                y: isElevated ? 8 : 4
            )
    }

    private func highlight(for shape: RoundedRectangle) -> some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.58),
                        .white.opacity(0.16),
                        .black.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

struct LiquidGlassButtonStyleModifier: ViewModifier {
    let isProminent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

struct KeyboardKeySurfaceModifier: ViewModifier {
    let tint: Color?
    let isPressed: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: LiquidGlassStyle.keyRadius, style: .continuous)

        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(shape)
            .background {
                shape
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(Color.primary.opacity(isPressed ? 0.18 : 0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .offset(y: isPressed ? 1 : 0)
            .scaleEffect(isPressed ? 0.985 : 1)
    }
}

struct LiquidGlassGroup<Content: View>: View {
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}

extension View {
    func liquidGlassPanel(
        cornerRadius: CGFloat = LiquidGlassStyle.panelRadius,
        tint: Color = .white.opacity(0.07),
        isElevated: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassPanelModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                isElevated: isElevated
            )
        )
    }

    func liquidGlassButtonStyle(isProminent: Bool = false) -> some View {
        modifier(LiquidGlassButtonStyleModifier(isProminent: isProminent))
    }

    func keyboardKeySurface(tint: Color?, isPressed: Bool = false) -> some View {
        modifier(KeyboardKeySurfaceModifier(tint: tint, isPressed: isPressed))
    }
}
