import SwiftUI

struct CompassOverlay: View {
    let direction: DropDirection?

    var body: some View {
        ZStack {
            Color.black.opacity(0.10)
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                compassButton(for: .above, icon: "arrow.up")
                HStack(spacing: 10) {
                    compassButton(for: .left, icon: "arrow.left")
                    centerHint
                    compassButton(for: .right, icon: "arrow.right")
                }
                compassButton(for: .below, icon: "arrow.down")

                Text(direction.map(captionFor) ?? "Move cursor to pick a side")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
        }
    }

    private var centerHint: some View {
        VStack(spacing: 2) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text("Split")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 44, height: 44)
    }

    private func compassButton(for d: DropDirection, icon: String) -> some View {
        let isActive = direction == d
        return Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isActive ? Color.white : Color.primary.opacity(0.75))
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.accentColor : Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.08), value: isActive)
    }

    private func captionFor(_ d: DropDirection) -> String {
        switch d {
        case .above: return "Release to split above"
        case .below: return "Release to split below"
        case .left: return "Release to split left"
        case .right: return "Release to split right"
        }
    }
}
