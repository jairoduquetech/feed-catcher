import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// AddCategoryView — Modal para crear o editar una carpeta de feeds
// ──────────────────────────────────────────────────────────────────────────────

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingCategory: FeedCategory? = nil

    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColor: String = "#FF9500"

    private var isEditing: Bool { editingCategory != nil }

    // SF Symbols categorizados
    private let iconOptions: [(name: String, label: String)] = [
        ("folder.fill", "Carpeta"),
        ("newspaper.fill", "Noticias"),
        ("laptopcomputer", "Tecnología"),
        ("gamecontroller.fill", "Videojuegos"),
        ("chart.line.uptrend.xyaxis", "Finanzas"),
        ("music.note", "Música"),
        ("film.fill", "Cine & Series"),
        ("sportscourt.fill", "Deportes"),
        ("heart.fill", "Salud & Vida"),
        ("fork.knife", "Gastronomía"),
        ("airplane", "Viajes"),
        ("briefcase.fill", "Trabajo"),
        ("graduationcap.fill", "Educación"),
        ("camera.fill", "Fotografía"),
        ("paintpalette.fill", "Arte"),
        ("leaf.fill", "Naturaleza"),
        ("globe", "Internacional"),
        ("star.fill", "Favoritos"),
        ("bubble.left.and.bubble.right.fill", "Comunidad"),
        ("lightbulb.fill", "Ideas & Ciencia"),
    ]

    private let colorOptions: [String] = [
        "#FF9500", "#FF6B6B", "#FF2D55", "#AF52DE",
        "#5856D6", "#007AFF", "#00C7BE", "#34C759",
        "#FFCC00", "#FF6B35", "#1ABC9C", "#8E8E93",
    ]

    private var previewColor: Color {
        Color(hex: selectedColor) ?? .accentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Barra Superior ──────────────────────────────────────────────
            HStack {
                Text(isEditing ? "Editar carpeta" : "Nueva carpeta")
                    .font(.headline)
                    .foregroundStyle(.primary)

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

            // ── Contenido ───────────────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {

                    // Vista previa de la carpeta
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(previewColor.opacity(0.2))
                                .frame(width: 58, height: 58)

                            Image(systemName: selectedIcon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(previewColor)
                        }

                        Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Nombre de la carpeta" : name)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                    }
                    .padding(.top, 10)

                    // Campo de Nombre
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOMBRE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        TextField("Ej: Tecnología, Videojuegos, Noticias…", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                    }

                    // Selector de Ícono
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ÍCONO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(minimum: 40, maximum: 48), spacing: 8), count: 5),
                            spacing: 8
                        ) {
                            ForEach(iconOptions, id: \.name) { icon in
                                let isSelected = selectedIcon == icon.name
                                Button {
                                    selectedIcon = icon.name
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(isSelected ? previewColor.opacity(0.18) : Color.primary.opacity(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(isSelected ? previewColor : Color.clear, lineWidth: 1.5)
                                            )

                                        Image(systemName: icon.name)
                                            .font(.system(size: 17))
                                            .foregroundStyle(isSelected ? previewColor : Color.primary.opacity(0.75))
                                    }
                                    .frame(height: 38)
                                }
                                .buttonStyle(.plain)
                                .help(icon.label)
                            }
                        }
                    }

                    // Selector de Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COLOR")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(minimum: 30, maximum: 36), spacing: 8), count: 6),
                            spacing: 10
                        ) {
                            ForEach(colorOptions, id: \.self) { hex in
                                let isSelected = selectedColor.caseInsensitiveCompare(hex) == .orderedSame
                                let swatchColor = Color(hex: hex) ?? .gray

                                Button {
                                    selectedColor = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(swatchColor)
                                            .frame(width: 26, height: 26)

                                        if isSelected {
                                            Circle()
                                                .stroke(Color.primary.opacity(0.6), lineWidth: 2)
                                                .frame(width: 32, height: 32)

                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(height: 34)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }

            Divider()

            // ── Barra de Acciones ───────────────────────────────────────────
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(isEditing ? "Guardar" : "Crear carpeta") {
                    saveCategory()
                }
                .keyboardShortcut(.return)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 440, height: 530)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let cat = editingCategory {
                name = cat.name
                selectedIcon = cat.icon
                selectedColor = cat.colorHex
            }
        }
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let cat = editingCategory {
            cat.name = trimmedName
            cat.icon = selectedIcon
            cat.colorHex = selectedColor
        } else {
            let category = FeedCategory(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColor
            )
            modelContext.insert(category)
        }

        try? modelContext.save()
        dismiss()
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Color(hex:) extension
// ──────────────────────────────────────────────────────────────────────────────
extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
