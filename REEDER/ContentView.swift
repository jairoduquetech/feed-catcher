import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// ContentView v6 (Modo Claro/Oscuro del Sistema + Rendimiento)
// ──────────────────────────────────────────────────────────────────────────────

struct ContentView: View {
    @State private var sidebarSelection: SidebarItem = .all
    @State private var selectedArticle: Article? = nil
    @State private var showAddFeed = false
    @State private var settings = AppSettings.shared

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection, showAddFeed: $showAddFeed)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } content: {
            TimelineView(selection: sidebarSelection, selectedArticle: $selectedArticle)
                .navigationSplitViewColumnWidth(min: 280, ideal: 330)
        } detail: {
            if let article = selectedArticle {
                ArticleDetailView(article: article)
            } else {
                WelcomeDetailView()
            }
        }
        .sheet(isPresented: $showAddFeed) {
            AddFeedView()
        }
        .safeAreaInset(edge: .bottom) {
            MiniPlayerView()
        }
        .preferredColorScheme(settings.colorScheme.swiftUIScheme)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// WelcomeDetailView — Pantalla de bienvenida adaptable
// ──────────────────────────────────────────────────────────────────────────────
private struct WelcomeDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.8))
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 6) {
                Text("Feed Catcher")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(Color.primary)

                Text("Selecciona una noticia para comenzar a leer")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Consejos rápidos
            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "plus", tip: "Añade nuevos feeds con el botón + en la barra lateral")
                TipRow(icon: "square.and.arrow.down", tip: "Importa tus suscripciones desde Reeder 4 con el menú ⋯")
                TipRow(icon: "arrow.clockwise", tip: "Actualiza manualmente con ⌘R o automáticamente de fondo")
                TipRow(icon: "star", tip: "Guarda tus artículos favoritos con el botón ★")
                TipRow(icon: "paintpalette", tip: "Alterna entre Modo Claro y Oscuro en Ajustes (⌘,)")
            }
            .padding(20)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TipRow: View {
    let icon: String
    let tip: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(tip)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
