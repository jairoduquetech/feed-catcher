import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// AddFeedView v5 — Añadir Feeds RSS y Canales de YouTube con resolución de @handles
// ──────────────────────────────────────────────────────────────────────────────

struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feed.addedDate) private var existingFeeds: [Feed]

    enum FeedTypeTab: String, CaseIterable {
        case websites = "Webs & Blogs"
        case youtube = "YouTube"
    }

    @State private var selectedTab: FeedTypeTab = .websites
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
            // ── Cabecera ─────────────────────────────────────────────────────
            HStack {
                Text(selectedTab == .youtube ? "Añadir Canal de YouTube" : "Añadir Feed RSS")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                // Botón destacado de importar desde Reeder
                Button {
                    showOPMLImport = true
                } label: {
                    Label("Importar OPML", systemImage: "square.and.arrow.down.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Importa tus suscripciones en archivo OPML")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // Selector de tipo (Web vs YouTube)
            Picker("Tipo de suscripción", selection: $selectedTab) {
                ForEach(FeedTypeTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .onChange(of: selectedTab) { _, _ in
                errorMessage = nil
            }

            Divider()
                .padding(.bottom, 14)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Entrada de URL / Handle ──────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedTab == .youtube ? "HANDLE O ENLACE DEL CANAL" : "URL DEL FEED O SITIO WEB")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        HStack {
                            if selectedTab == .youtube {
                                Image(systemName: "play.rectangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.system(size: 14))
                            }

                            TextField(
                                selectedTab == .youtube ? "@mkbhd o https://youtube.com/@midudev" : "https://ejemplo.com/feed.xml",
                                text: $urlText
                            )
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

                    // ── Nombre del feed previsualizado ───────────────────────
                    if didPreview {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOMBRE DE LA SUSCRIPCIÓN")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                            TextField("Nombre", text: $feedTitle)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.primary)
                                .padding(10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Mensaje de error
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                    }

                    // ── Sugerencias según pestaña seleccionada ───────────────
                    if selectedTab == .youtube {
                        youtubeSuggestionsSection
                    } else {
                        websiteSuggestionsSection
                    }
                }
                .padding(.horizontal, 20)
            }
            .animation(.easeInOut(duration: 0.15), value: didPreview)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)

            Spacer()

            // Resultado de importación
            if let result = importResult {
                Label(result, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }

            Divider()

            // ── Botones inferiores ───────────────────────────────────────────
            HStack {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.escape)

                Spacer()

                if !didPreview {
                    Button(selectedTab == .youtube ? "Buscar Canal" : "Previsualizar Feed") {
                        Task { await preview() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .keyboardShortcut(.return)
                } else {
                    Button(selectedTab == .youtube ? "Seguir Canal" : "Añadir Feed") {
                        addFeed()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(feedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showOPMLImport,
            allowedContentTypes: [.init(filenameExtension: "opml") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleOPMLImport(result) }
        }
    }

    // MARK: - Secciones de sugerencias

    @ViewBuilder
    private var websiteSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SITIOS WEB POPULARES")
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

    @ViewBuilder
    private var youtubeSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CANALES DE YOUTUBE POPULARES")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(SuggestedYouTubeChannel.popular) { channel in
                    SuggestedYouTubeCell(channel: channel) {
                        urlText = channel.rssURL
                        feedTitle = channel.name
                        didPreview = true
                        errorMessage = nil
                    }
                }
            }
        }
    }

    // MARK: - Previsualizar

    private func preview() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var targetURL = trimmed

        // Si es consulta de YouTube o estamos en la pestaña de YouTube
        if selectedTab == .youtube || YouTubeService.isYouTubeQuery(trimmed) {
            if let resolved = await YouTubeService.shared.resolveToRSS(query: trimmed) {
                targetURL = resolved
            } else if !trimmed.contains("youtube.com/feeds/videos.xml") {
                errorMessage = "No se pudo encontrar el canal de YouTube. Prueba con el handle (ej: @mkbhd) o la URL del canal."
                didPreview = false
                return
            }
        }

        do {
            let parsed = try await RSSService.shared.fetchFeed(urlString: targetURL)
            feedTitle = parsed.title
            urlText = targetURL
            didPreview = true
        } catch {
            errorMessage = error.localizedDescription
            didPreview = false
        }
    }

    // MARK: - Añadir feed individual

    private func addFeed() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
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
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(suggestion.category)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(10)
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
// SuggestedYouTubeCell
// ──────────────────────────────────────────────────────────────────────────────
private struct SuggestedYouTubeCell: View {
    let channel: SuggestedYouTubeChannel
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(channel.handle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text(channel.category)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .lineLimit(1)
                }

                Spacer()
            }
            .padding(8)
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
