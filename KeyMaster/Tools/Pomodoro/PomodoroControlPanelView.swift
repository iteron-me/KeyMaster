import SwiftUI

struct PomodoroControlPanelView: View {
    @ObservedObject var timer: PomodoroTimer
    let close: () -> Void

    @State private var hoveredControl: PomodoroControlHint?

    var body: some View {
        ZStack {
            panelContent
        }
        .frame(width: 236, height: 156)
        .background(Color.clear)
    }

    private var panelContent: some View {
        VStack(spacing: 11) {
            header

            Text(timer.formattedRemaining)
                .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            progressBar

            controls
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(width: 220, height: 140)
        .liquidGlassPanel(
            cornerRadius: 18,
            tint: phaseTint.opacity(0.12),
            isElevated: false,
            usesMaterial: true,
            showsShadow: false
        )
        .overlay(alignment: .bottom) {
            if let hoveredControl, let tooltipTitle = tooltipTitle(for: hoveredControl) {
                Text(tooltipTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                    .padding(.bottom, 43)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredControl)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: timer.phase == .focus ? "timer" : "cup.and.saucer.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(phaseTint)
                .frame(width: 16, height: 16)

            Text(timer.mode == .paused ? "Paused" : timer.phaseTitle)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(PomodoroIconButtonStyle(tint: .secondary, isProminent: false))
            .help("Close (Esc)")
            .onHover { updateHover(.close, isHovered: $0) }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))

                Capsule()
                    .fill(phaseTint)
                    .frame(width: max(proxy.size.width * timer.progressFraction, 4))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button {
                timer.togglePrimaryAction()
            } label: {
                Image(systemName: timer.primaryActionSystemImage)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 28)
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(PomodoroIconButtonStyle(tint: phaseTint, isProminent: true))
            .help("\(timer.primaryActionTitle) (Space)")
            .onHover { updateHover(.primary, isHovered: $0) }

            if timer.mode != .idle {
                Button {
                    timer.skip()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 28)
                }
                .keyboardShortcut("n", modifiers: [])
                .buttonStyle(PomodoroIconButtonStyle(tint: .blue, isProminent: false))
                .help("Skip (N)")
                .onHover { updateHover(.skip, isHovered: $0) }

                Button {
                    timer.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 32, height: 28)
                }
                .keyboardShortcut("s", modifiers: [])
                .buttonStyle(PomodoroIconButtonStyle(tint: .red, isProminent: false))
                .help("Stop (S)")
                .onHover { updateHover(.stop, isHovered: $0) }
            }
        }
        .frame(height: 28)
    }

    private func updateHover(_ control: PomodoroControlHint, isHovered: Bool) {
        if isHovered {
            hoveredControl = control
        } else if hoveredControl == control {
            hoveredControl = nil
        }
    }

    private func tooltipTitle(for control: PomodoroControlHint) -> String? {
        switch control {
        case .close:
            "Close (Esc)"
        case .primary:
            "\(timer.primaryActionTitle) (Space)"
        case .skip:
            timer.mode == .idle ? nil : "Skip (N)"
        case .stop:
            timer.mode == .idle ? nil : "Stop (S)"
        }
    }

    private var phaseTint: Color {
        switch timer.phase {
        case .focus:
            .red
        case .shortBreak:
            .green
        case .longBreak:
            .blue
        case nil:
            .red
        }
    }
}

private enum PomodoroControlHint: Equatable {
    case close
    case primary
    case skip
    case stop
}

private struct PomodoroIconButtonStyle: ButtonStyle {
    let tint: Color
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isProminent ? .white : tint)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isProminent ? tint : Color.primary.opacity(configuration.isPressed ? 0.14 : 0.07))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isProminent ? 0 : 0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
