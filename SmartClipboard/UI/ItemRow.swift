import SwiftUI
import AppKit

struct ItemRow: View {
    let item: ClipItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 36, height: 36)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .font(.system(size: 13))
                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    if let src = item.sourceApp {
                        Text(src).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Text(relativeTime).font(.caption2).foregroundStyle(.tertiary)
                    Text(byteString).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 4)
            if item.isStarred {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 11))
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.contentType {
        case .image:
            if let img = item.thumbnailImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        case .files:
            Image(systemName: "folder").foregroundStyle(.secondary).font(.system(size: 18))
        case .text:
            Image(systemName: "doc.text").foregroundStyle(.secondary).font(.system(size: 18))
        }
    }

    private var typeLabel: String {
        switch item.contentType {
        case .text: return "TEXT"
        case .image: return "IMG"
        case .files: return "FILES"
        }
    }

    private var relativeTime: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: item.createdAt, relativeTo: Date())
    }

    private var byteString: String {
        ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file)
    }
}
