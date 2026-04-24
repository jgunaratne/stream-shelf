import SwiftUI

struct MetaChip: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(text)
                .font(StreamShelfTheme.Typography.metaLabel)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(StreamShelfTheme.Colors.surfaceElevated)
        .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(StreamShelfTheme.Colors.separator)
        )
    }
}

struct MetaChipRow: View {
    let chips: [ChipItem]

    struct ChipItem: Identifiable {
        let id = UUID()
        let text: String
        var icon: String? = nil
    }

    var body: some View {
        HStack(spacing: StreamShelfTheme.Spacing.xs) {
            ForEach(chips) { chip in
                MetaChip(text: chip.text, icon: chip.icon)
            }
        }
    }
}
