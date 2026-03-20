import SwiftUI

struct ToastView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 6)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("ToastView") {
    VStack {
        Spacer()
        ToastView(title: "Saved", message: "Your changes were synced locally.")
            .padding()
        Spacer()
    }
    .frame(width: 420, height: 220)
    .background(DesignSystem.Colors.window)
}
#endif
