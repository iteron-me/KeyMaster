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
            .glassEffect(.clear.tint(tint), in: shape)
            .overlay(highlight(for: shape))
            .shadow(color: .black.opacity(isElevated ? 0.10 : 0.04), radius: isElevated ? 16 : 8, y: isElevated ? 8 : 4)
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
    }
}

struct LiquidGlassButtonStyleModifier: ViewModifier {
    let isProminent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

struct KeyboardKeyButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: LiquidGlassStyle.keyRadius, style: .continuous)

        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(shape)
            .background {
                keyBackground(in: shape, isPressed: configuration.isPressed)
            }
            .overlay {
                keyStroke(for: shape, isPressed: configuration.isPressed)
            }
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.04 : shadowOpacity),
                radius: configuration.isPressed ? 2 : 5,
                y: configuration.isPressed ? 1 : 3
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }

    @ViewBuilder
    private func keyBackground(in shape: RoundedRectangle, isPressed: Bool) -> some View {
        shape
            .fill(Color(nsColor: .controlBackgroundColor))

        shape
            .fill(
                LinearGradient(
                    colors: surfaceColors(isPressed: isPressed),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        if let tint {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(isPressed ? 0.16 : 0.11),
                            tint.opacity(isPressed ? 0.07 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }

        shape
            .inset(by: 1)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(isPressed ? 0.18 : topHighlightOpacity),
                        .white.opacity(0.02),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }

    private func keyStroke(for shape: RoundedRectangle, isPressed: Bool) -> some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(isPressed ? 0.22 : strokeHighlightOpacity),
                        .white.opacity(colorScheme == .dark ? 0.08 : 0.22),
                        .black.opacity(isPressed ? 0.20 : 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
    }

    private func surfaceColors(isPressed: Bool) -> [Color] {
        if colorScheme == .dark {
            [
                .white.opacity(isPressed ? 0.06 : 0.12),
                .white.opacity(isPressed ? 0.03 : 0.07),
                .black.opacity(isPressed ? 0.24 : 0.16)
            ]
        } else {
            [
                .white.opacity(isPressed ? 0.34 : 0.58),
                .white.opacity(isPressed ? 0.12 : 0.26),
                .black.opacity(isPressed ? 0.10 : 0.045)
            ]
        }
    }

    private var shadowOpacity: Double {
        colorScheme == .dark ? 0.24 : 0.12
    }

    private var strokeHighlightOpacity: Double {
        colorScheme == .dark ? 0.32 : 0.72
    }

    private var topHighlightOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.40
    }
}

struct LiquidGlassGroup<Content: View>: View {
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: spacing, content: content)
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
}
