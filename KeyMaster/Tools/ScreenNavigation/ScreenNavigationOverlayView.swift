import SwiftUI

struct ScreenNavigationOverlayView: View {
    @ObservedObject var state: ScreenNavigationOverlayState
    let screenFrame: CGRect

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            ForEach(visibleTargets) { target in
                HintBadge(
                    hint: target.hint,
                    isMatched: isMatched(target)
                )
                .position(anchorPoint(for: target.frame, in: screenFrame))
                .help(target.label)
            }

            if let message = state.message {
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .position(x: screenFrame.width / 2, y: screenFrame.height / 2)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }

    private var visibleTargets: [ScreenNavigationHintTarget] {
        state.targets.filter { target in
            guard intersects(target.frame, screenFrame) else {
                return false
            }

            guard !state.inputPrefix.isEmpty else {
                return true
            }

            return target.hint.hasPrefix(state.inputPrefix)
        }
    }

    private func isMatched(_ target: ScreenNavigationHintTarget) -> Bool {
        state.inputPrefix.isEmpty || target.hint.hasPrefix(state.inputPrefix)
    }

    private func anchorPoint(for frame: CGRect, in screenFrame: CGRect) -> CGPoint {
        let x = frame.minX - screenFrame.minX + Self.badgeOffset.width
        let y = frame.minY - screenFrame.minY + Self.badgeOffset.height

        return CGPoint(
            x: min(max(x, Self.edgePadding.width), screenFrame.width - Self.edgePadding.width),
            y: min(max(y, Self.edgePadding.height), screenFrame.height - Self.edgePadding.height)
        )
    }

    private func intersects(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        !lhs.intersection(rhs).isNull
    }

    private static let edgePadding = CGSize(width: 12, height: 9)
    private static let badgeOffset = CGSize(width: 8, height: 7)
}

private struct HintBadge: View {
    let hint: String
    let isMatched: Bool

    var body: some View {
        Text(hint)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(isMatched ? .black.opacity(0.86) : .white.opacity(0.66))
            .padding(.horizontal, 4)
            .frame(height: 14)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isMatched ? Color.yellow.opacity(0.62) : Color.black.opacity(0.32))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
    }
}
