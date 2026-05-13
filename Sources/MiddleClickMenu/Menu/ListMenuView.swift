import SwiftUI

struct ListMenuView: View {
    let actions: [any MenuAction]
    let selectedText: String?
    let isActionEnabled: (any MenuAction) -> Bool
    let onSelect: (any MenuAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                if index > 0 {
                    Divider().padding(.horizontal, 8)
                }
                Button {
                    onSelect(action)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text(action.name)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isActionEnabled(action))
                .opacity(isActionEnabled(action) ? 1.0 : 0.4)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 180)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}
