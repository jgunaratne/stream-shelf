import SwiftUI

struct ErrorView: View {
    let message: String
    let retry: (() -> Void)?

    init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: StreamShelfTheme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(StreamShelfTheme.Colors.warning)
            Text("Something went wrong")
                .font(.headline)
                .foregroundStyle(StreamShelfTheme.Colors.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if let retry {
                Button(action: retry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(StreamShelfTheme.Colors.accent)
            }
        }
        .padding(StreamShelfTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StreamShelfTheme.Colors.appBackground)
    }
}

#Preview {
    ErrorView(message: "Could not connect to server.") {}
}
