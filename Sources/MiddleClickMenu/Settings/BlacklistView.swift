import SwiftUI

struct BlacklistView: View {
    @Binding var blacklistApps: [String]
    @State private var newBundleId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("黑名单应用")
                .font(.headline)
            Text("在以下应用中禁用鼠标中键拦截")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(blacklistApps, id: \.self) { bundleId in
                    HStack {
                        Text(bundleId)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    blacklistApps.remove(atOffsets: indexSet)
                }
            }
            .frame(minHeight: 100)

            HStack {
                TextField("Bundle ID (如 com.blender.Blender)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    let trimmed = newBundleId.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !blacklistApps.contains(trimmed) else { return }
                    blacklistApps.append(trimmed)
                    newBundleId = ""
                }
                .disabled(newBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}
