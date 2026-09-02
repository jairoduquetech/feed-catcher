import SwiftUI
import SwiftData

@main
struct REEDERApp: App {

    @State private var modelContainer: ModelContainer = {
        let schema = Schema([Feed.self, Article.self, FeedCategory.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: config)
    }()

    var body: some Scene {
        // ── Ventana principal ────────────────────────────────────────────────
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 620)
                .onAppear {
                    startBackgroundRefresh()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .modelContainer(modelContainer)
        .commands {
            // ── Menú de la Aplicación (Feed Catcher) ──────────────────────────
            CommandGroup(replacing: .appInfo) {
                Button("Acerca de Feed Catcher") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Feed Catcher",
                            NSApplication.AboutPanelOptionKey.version: "1.6"
                        ]
                    )
                }
            }

            CommandGroup(replacing: .appVisibility) {
                Button("Ocultar Feed Catcher") {
                    NSApplication.shared.hide(nil)
                }
                .keyboardShortcut("h", modifiers: [.command])

                Button("Ocultar otros") {
                    NSApplication.shared.hideOtherApplications(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])

                Button("Mostrar todo") {
                    NSApplication.shared.unhideAllApplications(nil)
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("Salir de Feed Catcher") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }

            // ── Menú Archivo ─────────────────────────────────────────────────
            CommandGroup(after: .newItem) {
                Divider()
                Button("Actualizar todos los feeds") {
                    FeedRefreshService.shared.triggerManualRefresh(modelContainer: modelContainer)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            // ── Menú Ver ─────────────────────────────────────────────────────
            CommandGroup(after: .toolbar) {
                Divider()
                Menu("Tema") {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Button(scheme.rawValue) {
                            AppSettings.shared.colorScheme = scheme
                        }
                    }
                }
            }

            // Comandos de barra lateral
            SidebarCommands()

            // ── Menú Ayuda ───────────────────────────────────────────────────
            CommandGroup(replacing: .help) {
                Button("Ayuda de Feed Catcher") {
                    if let url = URL(string: "https://google.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        // ── Ventana de Ajustes (⌘,) ──────────────────────────────────────────
        Settings {
            SettingsView()
        }
    }

    // MARK: - Actualización en segundo plano

    private func startBackgroundRefresh() {
        let settings = AppSettings.shared
        FeedRefreshService.shared.refreshInterval = settings.refreshIntervalMinutes * 60
        if settings.autoRefreshEnabled {
            FeedRefreshService.shared.start(modelContainer: modelContainer)
        }
    }
}
