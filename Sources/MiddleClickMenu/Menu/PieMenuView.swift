import SwiftUI

struct PieMenuView: View {
    let actions: [any MenuAction]
    let selectedText: String?
    let isActionEnabled: (any MenuAction) -> Bool
    let onSelect: (any MenuAction) -> Void

    @State private var hoveredIndex: Int? = nil

    private let radius: CGFloat = 90
    private let itemSize: CGFloat = 60
    private let canvasSize: CGFloat = 260

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 30, height: 30)

            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                let angle = angleForIndex(index, total: actions.count)
                let enabled = isActionEnabled(action)
                let isHovered = hoveredIndex == index

                Button {
                    if enabled { onSelect(action) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 18))
                        Text(action.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .frame(width: itemSize, height: itemSize)
                    .background(
                        Circle()
                            .fill(isHovered ? Color.accentColor.opacity(0.3) : Color.clear)
                    )
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .opacity(enabled ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
                .offset(
                    x: radius * cos(angle),
                    y: radius * sin(angle)
                )
                .onHover { isHovering in
                    hoveredIndex = isHovering ? index : nil
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    private func angleForIndex(_ index: Int, total: Int) -> CGFloat {
        let startAngle = -CGFloat.pi / 2
        let step = (2 * CGFloat.pi) / CGFloat(total)
        return startAngle + step * CGFloat(index)
    }
}
