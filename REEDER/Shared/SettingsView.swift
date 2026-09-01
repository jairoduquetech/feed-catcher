import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// AppSettings v5 (Español + Modo Claro/Oscuro + Rendimiento)
// Preferencias globales observables con soporte para tema de sistema y personalización
// ──────────────────────────────────────────────────────────────────────────────

@Observable
final class AppSettings {
    static let shared = AppSettings()
    private init() {}

    // Apariencia
    var colorScheme: AppColorScheme = .system
    var showThumbnails: Bool = true
    var showFavicons: Bool = true
    var showSummaries: Bool = true
    var compactRowDensity: Bool = false

    // Lectura
    var fontSize: Double = 17
    var fontFamily: ReaderFont = .sansSerif
    var lineSpacingRatio: Double = 1.75

    // Sincronización
    var autoRefreshEnabled: Bool = true
    var refreshIntervalMinutes: Double = 30
}

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "Sistema"
    case light  = "Claro"
    case dark   = "Oscuro"

    var id: String { rawValue }

    var swiftUIScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum ReaderFont: String, CaseIterable, Identifiable {
    case sansSerif = "Sans-Serif (Sistema)"
    case serif     = "Serif (Georgia)"
    case rounded   = "Redondeada"
    case monospace = "Monoespaciada"

    var id: String { rawValue }

    var cssValue: String {
        switch self {
        case .sansSerif: return #"-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif"#
        case .serif:     return #"Georgia, "Times New Roman", serif"#
        case .rounded:   return #""SF Pro Rounded", "Comic Sans MS", -apple-system, sans-serif"#
        case .monospace: return #""SF Mono", "Menlo", "Consolas", monospace"#
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SettingsView (Ventana de Ajustes ⌘,)
// ──────────────────────────────────────────────────────────────────────────────

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var selectedTab = SettingsTab.appearance
    @State private var cacheSizeText = ImageCacheService.shared.cacheSizeInMB
    @State private var showCacheCleared = false

    var body: some View {
        TabView(selection: $selectedTab) {
            AppearanceSettingsTab(settings: settings)
                .tabItem { Label("Apariencia", systemImage: "paintpalette") }
                .tag(SettingsTab.appearance)

            ReadingSettingsTab(settings: settings)
                .tabItem { Label("Lectura", systemImage: "text.alignleft") }
                .tag(SettingsTab.reading)

            SyncSettingsTab(
                settings: settings,
                cacheSizeText: $cacheSizeText,
                showCacheCleared: $showCacheCleared
            )
            .tabItem { Label("Sincronización", systemImage: "arrow.triangle.2.circlepath") }
            .tag(SettingsTab.sync)
        }
        .frame(width: 480, height: 340)
    }
}

private enum SettingsTab { case appearance, reading, sync }

// MARK: — Pestaña Apariencia

private struct AppearanceSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Tema de la Interfaz") {
                Picker("Apariencia", selection: $settings.colorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)

                Text("Si eliges 'Sistema', la app alternará entre modo claro y oscuro según la configuración de tu Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Lista de Noticias") {
                Toggle("Mostrar miniaturas de fotos", isOn: $settings.showThumbnails)
                Toggle("Mostrar favicons de los sitios", isOn: $settings.showFavicons)
                Toggle("Mostrar resumen de 2 líneas", isOn: $settings.showSummaries)
                Toggle("Filas compactas (mayor densidad)", isOn: $settings.compactRowDensity)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: — Pestaña Lectura

private struct ReadingSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Tipografía del Artículo") {
                Picker("Familia de fuente", selection: $settings.fontFamily) {
                    ForEach(ReaderFont.allCases) { font in
                        Text(font.rawValue).tag(font)
                    }
                }

                HStack {
                    Text("Tamaño de letra")
                    Slider(value: $settings.fontSize, in: 13...24, step: 1)
                    Text("\(Int(settings.fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                }

                // Muestra previa en vivo
                VStack(alignment: .leading, spacing: 4) {
                    Text("VISTA PREVIA")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text("El rápido zorro marrón salta sobre el perro perezoso.")
                        .font(previewFont)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var previewFont: Font {
        switch settings.fontFamily {
        case .sansSerif: return .system(size: CGFloat(settings.fontSize))
        case .serif:     return .system(size: CGFloat(settings.fontSize), design: .serif)
        case .rounded:   return .system(size: CGFloat(settings.fontSize), design: .rounded)
        case .monospace: return .system(size: CGFloat(settings.fontSize), design: .monospaced)
        }
    }
}

// MARK: — Pestaña Sincronización y Rendimiento

private struct SyncSettingsTab: View {
    @Bindable var settings: AppSettings
    @Binding var cacheSizeText: String
    @Binding var showCacheCleared: Bool

    var body: some View {
        Form {
            Section("Actualización Automática") {
                Toggle("Actualizar feeds automáticamente", isOn: $settings.autoRefreshEnabled)

                if settings.autoRefreshEnabled {
                    HStack {
                        Text("Intervalo")
                        Slider(value: $settings.refreshIntervalMinutes,
                               in: 5...120, step: 5) { _ in
                            FeedRefreshService.shared.refreshInterval = settings.refreshIntervalMinutes * 60
                        }
                        Text("\(Int(settings.refreshIntervalMinutes)) min")
                            .monospacedDigit()
                            .frame(width: 55, alignment: .trailing)
                    }
                }
            }

            Section("Caché y Rendimiento") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Espacio en disco ocupado por imágenes")
                        Text(cacheSizeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Vaciar Caché") {
                        ImageCacheService.shared.clearCache()
                        cacheSizeText = ImageCacheService.shared.cacheSizeInMB
                        showCacheCleared = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCacheCleared = false
                        }
                    }
                }

                if showCacheCleared {
                    Text("✓ Caché vaciada correctamente")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
