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
    let usesMaterial: Bool
    let showsShadow: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let panel = content
            .background {
                if usesMaterial {
                    shape
                        .fill(.regularMaterial)
                        .allowsHitTesting(false)
                } else {
                    shape
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.86))
                        .allowsHitTesting(false)
                }

                shape
                    .fill(tint)
                    .allowsHitTesting(false)
            }
            .overlay(highlight(for: shape))

        if showsShadow {
            panel
                .shadow(
                    color: .black.opacity(isElevated ? 0.10 : 0.04),
                    radius: isElevated ? 16 : 8,
                    y: isElevated ? 8 : 4
                )
        } else {
            panel
        }
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
    let isHovered: Bool

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
                    .fill(Color.primary.opacity(isHovered ? 0.045 : 0))
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(
                        Color.primary.opacity(isPressed || isHovered ? 0.22 : 0.12),
                        lineWidth: isHovered ? 1.4 : 1
                    )
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(isHovered && !isPressed ? 0.10 : 0),
                radius: 5,
                y: 2
            )
            .offset(y: isPressed ? 1 : (isHovered ? -1 : 0))
            .scaleEffect(isPressed ? 0.985 : (isHovered ? 1.012 : 1))
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: isPressed)
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
        isElevated: Bool = false,
        usesMaterial: Bool = false,
        showsShadow: Bool = true
    ) -> some View {
        modifier(
            LiquidGlassPanelModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                isElevated: isElevated,
                usesMaterial: usesMaterial,
                showsShadow: showsShadow
            )
        )
    }

    func liquidGlassButtonStyle(isProminent: Bool = false) -> some View {
        modifier(LiquidGlassButtonStyleModifier(isProminent: isProminent))
    }

    func keyboardKeySurface(
        tint: Color?,
        isPressed: Bool = false,
        isHovered: Bool = false
    ) -> some View {
        modifier(
            KeyboardKeySurfaceModifier(
                tint: tint,
                isPressed: isPressed,
                isHovered: isHovered
            )
        )
    }
}
