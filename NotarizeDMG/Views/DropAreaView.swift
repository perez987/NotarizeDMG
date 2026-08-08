import SwiftUI
import UniformTypeIdentifiers

struct DropAreaView: View {
    @Binding var fileURL: URL?
    @Binding var isTargeted: Bool
    var mode: AppMode
    var onBrowse: () -> Void

    private var acceptedType: UTType {
        mode == .notarize
            ? (UTType(filenameExtension: "dmg") ?? .data)
            : (UTType(filenameExtension: "app") ?? .bundle)
    }

    private var placeholderKey: String {
        mode == .notarize ? "drop_dmg_here" : "drop_app_here"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted
                    ? Color.accentColor.opacity(0.08)
                    : Color.secondary.opacity(0.05))

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.dotted")
                    .font(.system(size: 44))
                    .foregroundStyle(isTargeted ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(Color.secondary))

                if let url = fileURL {
                    VStack(spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.headline)
                        Text(url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text(NSLocalizedString(placeholderKey, comment: "Drop placeholder"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Button(NSLocalizedString("browse", comment: "Browse button"), action: onBrowse)
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(height: 160)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard
                let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            let ext = url.pathExtension.lowercased()
            let expected = mode == .notarize ? "dmg" : "app"
            guard ext == expected else { return }
            DispatchQueue.main.async { fileURL = url }
        }
        return true
    }
}
