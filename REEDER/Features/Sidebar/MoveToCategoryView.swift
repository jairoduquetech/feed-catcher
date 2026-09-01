import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// MoveToCategoryView — Sheet para mover un feed a una carpeta
// ──────────────────────────────────────────────────────────────────────────────

struct MoveToCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let feed: Feed
    @Query(sort: \FeedCategory.sortOrder) private var categories: [FeedCategory]

    var body: some View {
        VStack(spacing: 0) {
            // Cabecera
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mover a carpeta")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(feed.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary.opacity(0.8))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    // Opción sin carpeta
                    CategoryOptionRow(
                        icon: "minus.circle",
                        iconColor: .secondary,
                        name: "Sin carpeta",
                        isSelected: feed.category == nil
                    ) {
                        feed.category = nil
                        try? modelContext.save()
                        dismiss()
                    }

                    if !categories.isEmpty {
                        Divider().padding(.horizontal, 16).padding(.vertical, 4)
                    }

                    // Carpetas disponibles
                    ForEach(categories) { category in
                        CategoryOptionRow(
                            icon: category.icon,
                            iconColor: Color(hex: category.colorHex) ?? .gray,
                            name: category.name,
                            isSelected: feed.category?.id == category.id
                        ) {
                            feed.category = category
                            try? modelContext.save()
                            dismiss()
                        }
                    }

                    if categories.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary.opacity(0.4))
                            Text("No tienes carpetas todavía")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("Crea una carpeta con el botón + en la barra lateral")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cerrar") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct CategoryOptionRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(iconColor)
                }

                Text(name)
                    .font(.body)
                    .foregroundStyle(Color.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
