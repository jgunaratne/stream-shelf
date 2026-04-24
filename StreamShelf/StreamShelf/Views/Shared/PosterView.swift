import SwiftUI

struct PosterView: View {
    let url: URL?
    var width: CGFloat = StreamShelfTheme.Dimensions.posterWidth
    var height: CGFloat = StreamShelfTheme.Dimensions.posterHeight
    var cornerRadius: CGFloat = StreamShelfTheme.Dimensions.posterCornerRadius

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholderView
            case .empty:
                StreamShelfTheme.Colors.surface
                    .overlay(ProgressView().tint(StreamShelfTheme.Colors.accent))
            @unknown default:
                placeholderView
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }

    private var placeholderView: some View {
        StreamShelfTheme.Colors.surface
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: 22))
                    .foregroundStyle(StreamShelfTheme.Colors.tertiaryText)
            )
    }
}
