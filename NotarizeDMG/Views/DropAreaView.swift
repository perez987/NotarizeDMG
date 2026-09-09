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

    private var iconName: String {
        mode == .notarize ? "externaldrive.badge.checkmark" : "shippingbox.fill"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.surfaceGradient)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.accentGlow)
                        .opacity(isTargeted ? 0.95 : 0.45)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            isTargeted ? AppTheme.accentGradient : AppTheme.borderGradient,
                            style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [10, 6])
                        )
                }
                .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 14)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentGradient)
                        .opacity(isTargeted ? 0.9 : 0.72)
                        .frame(width: 68, height: 68)
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 52, height: 52)
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.accentGradient)
                }

                if let url = fileURL {
                    VStack(spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.headline.weight(.semibold))
                        Text(url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text(NSLocalizedString(placeholderKey, comment: "Drop placeholder"))
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.82))
                }

                Button(NSLocalizedString("browse", comment: "Browse button"), action: onBrowse)
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.28))
                    .foregroundStyle(.primary)
            }
            .padding(24)
        }
        .frame(height: 188)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isTargeted)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: fileURL)
        .onDrop(of: [acceptedType, .fileURL], isTargeted: $isTargeted, perform: handleDrop)
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
