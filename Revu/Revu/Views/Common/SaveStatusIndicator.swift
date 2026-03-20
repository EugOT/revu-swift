import SwiftUI

struct SaveStatusIndicator: View {
    let status: SaveStatusService.Status

    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
            case .saving:
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
                    .symbolEffect(.pulse, options: .repeating)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.feedbackSuccess)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.feedbackError)
            }
        }
        .animation(DesignSystem.Animation.smooth, value: status)
    }
}
