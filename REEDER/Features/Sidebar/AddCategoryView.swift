import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// AddCategoryView — Modal para crear o editar una categoría
// ──────────────────────────────────────────────────────────────────────────────

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingCategory: FeedCategory? = nil

    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColor: String = "#888888"

    private var isEditing: Bool { editingCategory != nil }

    // SF Symbols disponibles para categorías
    private let iconOptions: [(name: String, label: String)] = [
        ("folder.fill", "Carpeta"),
        ("newspaper.fill", "Noticias"),
        ("laptopcomputer", "Tecnología"),
        ("gamecontroller.fill", "Videojuegos"),
        ("music.note", "Música"),
        ("film.fill", "Entretenimiento"),
        ("sportscourt.fill", "Deportes"),
        ("chart.bar.fill", "Finanzas"),
        ("heart.fill", "Salud"),
        ("fork.knife", "Gastronomía"),
        ("airplane", "Viajes"),
        ("briefcase.fill", "Trabajo"),
        ("graduationcap.fill", "Educación"),
        ("camera.fill", "Fotografía"),
        ("paintpalette.fill", "Arte"),
        ("leaf.fill", "Naturaleza"),
        ("globe", "Internacional"),
        ("star.fill", "Favoritos"),
        ("bell.fill", "Notificaciones"),
        ("lightbulb.fill", "Ideas"),
    ]

    private let colorOptions: [String] = [
        "#888888", "#FF6B6B", "#FF9500", "#FFCC00",
        "#34C759", "#00C7BE", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#FF6B35", "#1ABC9C",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Cabecera
            HStack {
                Text(isEditing ? "Editar categoría" : "Nueva categoría")
                    .font(.headline)
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
                VStack(alignment: .leading, spacing: 24) {

                    // ── Vista previa ─────────────────────────────────────────
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: selectedColor) ?? .gray)
                                    .frame(width: 52, height: 52)
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(.white)
                            }
                            Text(name.isEmpty ? "Mi categoría" : name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)

                    // ── Nombre ───────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOMBRE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        TextField("Ej: Tecnología, Deportes…", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // ── Ícono ────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ÍCONO")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 8), count: 8), spacing: 8) {
                            ForEach(iconOptions, id: \.name) { icon in
                                Button {
                                    selectedIcon = icon.name
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedIcon == icon.name
                                                  ? (Color(hex: selectedColor) ?? .accentColor)
                                                  : Color.secondary.opacity(0.1))
                                        Image(systemName: icon.name)
                                            .font(.system(size: 18))
                                            .foregroundStyle(selectedIcon == icon.name ? .white : Color.primary.opacity(0.7))
                                    }
                                    .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .help(icon.label)
                            }
                        }
                    }

                    // ── Color ────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("COLOR")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Button {
                                    selectedColor = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex) ?? .gray)
                                            .frame(width: 28, height: 28)
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Acciones
            HStack {
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.escape)

                Spacer()

                Button(isEditing ? "Guardar" : "Crear categoría") {
                    saveCategory()
                }
                .keyboardShortcut(.return)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 420, height: 520)
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
