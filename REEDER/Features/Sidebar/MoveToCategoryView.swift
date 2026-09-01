import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// MoveToCategoryView — Sheet para mover un feed a una categoría
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
                    Text("Mover a categoría")
                        .font(.headline)
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
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    // Opción sin categoría
                    CategoryOptionRow(
                        icon: "minus.circle",
                        iconColor: .secondary,
                        name: "Sin categoría",
                        isSelected: feed.category == nil
                    ) {
                        feed.category = nil
                        try? modelContext.save()
                        dismiss()
                    }

                    Divider().padding(.horizontal, 16)

                    // Categorías disponibles
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
                            Text("No tienes categorías todavía")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("Crea una categoría con el botón + en la barra lateral")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(16)
        }
        .frame(width: 300, height: 380)
    }
}

private struct CategoryOptionRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 15))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
