import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// AddFeedView v4 (Español)
// Modal para añadir feeds individuales o importar desde Reeder 4
// ──────────────────────────────────────────────────────────────────────────────

struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feed.addedDate) private var existingFeeds: [Feed]

    @State private var urlText = ""
    @State private var feedTitle = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didPreview = false
    @State private var showOPMLImport = false
    @State private var isImporting = false
    @State private var importResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabecera
            HStack {
                Text("Añadir Feed")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                // Botón destacado de importar desde Reeder
                Button {
                    showOPMLImport = true
                } label: {
                    Label("Importar de Reeder 4", systemImage: "square.and.arrow.down.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Importa tus suscripciones de Reeder 4 u otro lector RSS en archivo OPML")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Instrucción rápida para Reeder 4
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                    .font(.caption)
                Text("En Reeder 4: Ajustes → Tus datos → Exportar OPML")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Divider()
                .padding(.bottom, 14)

        VStack(alignment: .leading, spacing: 14) {
            // Entrada de URL
            VStack(alignment: .leading, spacing: 6) {
                Text("O AÑADE UN FEED POR URL")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                HStack {
                    TextField("https://ejemplo.com/feed.xml", text: $urlText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
                        .font(.body.monospaced())
                        .onSubmit { Task { await preview() } }
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

            // Nombre del feed
            if didPreview {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOMBRE DEL FEED")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    TextField("Mi Feed", text: $feedTitle)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }

            // Feeds sugeridos
            VStack(alignment: .leading, spacing: 6) {
                Text("SUGERIDOS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(SuggestedFeed.all, id: \.url) { s in
                        SuggestedFeedCell(suggestion: s) {
                            urlText = s.url
                            feedTitle = s.title
                            didPreview = true
                            errorMessage = nil
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.15), value: didPreview)

        Spacer()

        // Resultado de importación
        if let result = importResult {
            Label(result, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 20)
        }

        // Botones inferiores
        HStack {
            Button("Cancelar") { dismiss() }
                .foregroundStyle(.secondary)
                .keyboardShortcut(.escape)

                Spacer()

                if !didPreview {
                    Button("Previsualizar Feed") {
                        Task { await preview() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .keyboardShortcut(.return)
                } else {
                    Button("Añadir Feed") { addFeed() }
                        .buttonStyle(.borderedProminent)
                        .disabled(feedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.return)
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showOPMLImport,
            allowedContentTypes: [.init(filenameExtension: "opml") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleOPMLImport(result) }
        }
    }

    // MARK: - Previsualizar

    private func preview() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let parsed = try await RSSService.shared.fetchFeed(urlString: trimmed)
            feedTitle = parsed.title
            didPreview = true
        } catch {
            errorMessage = error.localizedDescription
            didPreview = false
        }
    }

    // MARK: - Añadir feed individual

    private func addFeed() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty, !feedTitle.isEmpty else { return }
        let feed = Feed(title: feedTitle, url: url)
        modelContext.insert(feed)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Importar OPML

    @MainActor
    private func handleOPMLImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            isImporting = true
            defer { isImporting = false }

            do {
                let entries = try await OPMLService.shared.parseOPML(at: url)
                let existingURLs = Set(existingFeeds.map(\.url))
                var newCount = 0
                for entry in entries where !existingURLs.contains(entry.xmlURL) {
                    modelContext.insert(Feed(title: entry.title, url: entry.xmlURL))
                    newCount += 1
                }
                try? modelContext.save()
                importResult = "\(newCount) feeds importados — cerrando en 2s"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SuggestedFeedCell
// ──────────────────────────────────────────────────────────────────────────────
private struct SuggestedFeedCell: View {
    let suggestion: SuggestedFeed
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(suggestion.category)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(isHovered ? 0.08 : 0.04),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Feeds sugeridos
// ──────────────────────────────────────────────────────────────────────────────
struct SuggestedFeed {
    let title: String
    let url: String
    let category: String

    static let all: [SuggestedFeed] = [
        SuggestedFeed(title: "Hacker News",      url: "https://news.ycombinator.com/rss",              category: "Tecnología"),
        SuggestedFeed(title: "The Verge",         url: "https://www.theverge.com/rss/index.xml",        category: "Tecnología"),
        SuggestedFeed(title: "NASA Noticias",     url: "https://www.nasa.gov/news-release/feed/",       category: "Ciencia"),
        SuggestedFeed(title: "BBC Mundo",         url: "https://feeds.bbci.co.uk/mundo/rss.xml",        category: "Noticias"),
        SuggestedFeed(title: "Applesfera",        url: "https://feeds.weblogssl.com/applesfera",       category: "Apple"),
        SuggestedFeed(title: "Xataka",            url: "https://feeds.weblogssl.com/xataka2",          category: "Tecnología"),
    ]
}
