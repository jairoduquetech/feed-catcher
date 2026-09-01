import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// TimelineView v7 (Categorías + Adaptable a Modo Claro/Oscuro + Rendimiento)
// ──────────────────────────────────────────────────────────────────────────────

enum ArticleFilter: String, CaseIterable, Identifiable {
    case all       = "Todos"
    case unread    = "No leídos"
    case favorites = "Favoritos"
    var id: String { rawValue }
}

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    let selection: SidebarItem
    @Binding var selectedArticle: Article?

    @State private var filter: ArticleFilter = .all
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    @Query(sort: \Feed.addedDate) private var feeds: [Feed]
    @Query(sort: \FeedCategory.sortOrder) private var categories: [FeedCategory]
    @Query(sort: \Article.publishDate, order: .reverse) private var allArticles: [Article]

    init(selection: SidebarItem, selectedArticle: Binding<Article?>) {
        self.selection = selection
        self._selectedArticle = selectedArticle
    }

    private var refreshService = FeedRefreshService.shared

    private var selectedFeed: Feed? {
        if case .feed(let id) = selection {
            return feeds.first(where: { $0.id == id })
        }
        return nil
    }

    private var selectedCategory: FeedCategory? {
        if case .category(let id) = selection {
            return categories.first(where: { $0.id == id })
        }
        return nil
    }

    private var navigationTitle: String {
        switch selection {
        case .all:              return "Todos los artículos"
        case .favorites:        return "Favoritos"
        case .category:         return selectedCategory?.name ?? "Carpeta"
        case .feed:             return selectedFeed?.title ?? "Feed"
        }
    }

    private var unreadCountText: String {
        let count = articles.filter { !$0.isRead }.count
        if count == 0 {
            return "Estás al día"
        } else if count == 1 {
            return "1 artículo sin leer"
        } else {
            return "\(count) artículos sin leer"
        }
    }

    // ── Artículos filtrados ──────────────────────────────────────────────────
    private var articles: [Article] {
        var result = allArticles

        // 1. Filtro lateral
        switch selection {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .category(let catID):
            result = result.filter { $0.feed?.category?.id == catID }
        case .feed(let feedID):
            result = result.filter { $0.feed?.id == feedID }
        }

        // 2. Filtro de estado
        switch filter {
        case .all:
            break
        case .unread:
            result = result.filter { !$0.isRead }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        // 3. Búsqueda
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                ($0.summary?.lowercased().contains(q) ?? false) ||
                ($0.feed?.title.lowercased().contains(q) ?? false) ||
                ($0.author?.lowercased().contains(q) ?? false)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Cabecera de la lista ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text(navigationTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(unreadCountText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Barra de filtros ─────────────────────────────────────────────
            FilterBar(selectedFilter: $filter)

            Divider()

            // ── Lista de artículos ───────────────────────────────────────────
            if articles.isEmpty {
                emptyStateView
            } else {
                List(articles) { article in
                    ArticleRowView(article: article)
                        .listRowBackground(
                            selectedArticle?.id == article.id
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedArticle = article
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                article.isRead.toggle()
                            } label: {
                                Label(article.isRead ? "Marcar no leído" : "Marcar leído",
                                      systemImage: article.isRead ? "envelope.badge" : "envelope.open")
                            }
                            .tint(Color.accentColor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                article.isFavorite.toggle()
                            } label: {
                                Label(article.isFavorite ? "Quitar de favoritos" : "Favorito",
                                      systemImage: article.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Buscar noticias…")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !articles.isEmpty {
                    Button {
                        articles.forEach { $0.isRead = true }
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .help("Marcar todo como leído")
                }

                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing || refreshService.isRefreshing {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing || refreshService.isRefreshing)
                .help("Actualizar (⌘R)")
            }
        }
        .onChange(of: selection) { _, _ in
            filter = .all
            searchText = ""
            selectedArticle = nil
            Task { await refresh() }
        }
        .task {
            if allArticles.isEmpty { await refresh() }
        }
        .overlay(alignment: .bottom) {
            if let error = errorMessage {
                ErrorBannerView(message: error) { errorMessage = nil }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: errorMessage)
    }

    // MARK: - Estado vacío

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.3))
            Text(emptyTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(emptySubtitle)
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch filter {
        case .favorites: return "star"
        case .unread:    return "envelope.open"
        default:         return selection == .all ? "newspaper" : "tray"
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "Sin resultados" }
        switch filter {
        case .favorites: return "No hay favoritos todavía"
        case .unread:    return "¡Estás al día!"
        default:
            switch selection {
            case .all:      return feeds.isEmpty ? "No hay feeds aún" : "No hay artículos"
            case .favorites: return "No hay favoritos todavía"
            case .category: return "Esta carpeta no tiene artículos"
            case .feed:     return "No hay artículos en este feed"
            }
        }
    }

    private var emptySubtitle: String {
        if !searchText.isEmpty { return "Prueba con otro término de búsqueda" }
        switch filter {
        case .favorites: return "Marca artículos con estrella para verlos aquí"
        case .unread:    return "Has leído todo el contenido"
        default:         return feeds.isEmpty ? "Añade un feed con el botón +" : "Actualiza (⌘R) para cargar noticias"
        }
    }

    // MARK: - Actualizar

    @MainActor
    private func refresh() async {
        let feedsToRefresh: [Feed]
        if let feed = selectedFeed {
            feedsToRefresh = [feed]
        } else if let category = selectedCategory {
            feedsToRefresh = category.feeds
        } else {
            feedsToRefresh = feeds
        }
        guard !feedsToRefresh.isEmpty else { return }

        withAnimation { isRefreshing = true }
        defer { withAnimation { isRefreshing = false } }

        var hasFailure = false
        var lastError: String? = nil

        for feed in feedsToRefresh {
            do {
                let parsed = try await RSSService.shared.fetchFeed(urlString: feed.url)
                let existingArticlesByUrl = Dictionary(grouping: feed.articles, by: \.articleURL)
                    .compactMapValues(\.first)

                for item in parsed.items {
                    if let existing = existingArticlesByUrl[item.url] {
                        if existing.imageURL == nil && item.imageURL != nil {
                            existing.imageURL = item.imageURL
                        }
                        if existing.author == nil && item.author != nil {
                            existing.author = item.author
                        }
                        if existing.content == nil && item.content != nil {
                            existing.content = item.content
                        }
                        if existing.summary == nil && item.summary != nil {
                            existing.summary = item.summary
                        }
                    } else {
                        let article = Article(
                            title: item.title,
                            articleURL: item.url,
                            summary: item.summary,
                            content: item.content,
                            imageURL: item.imageURL,
                            author: item.author,
                            publishDate: item.publishDate,
                            feed: feed
                        )
                        modelContext.insert(article)
                    }
                }
                if feed.title == feed.url || feed.title.isEmpty { feed.title = parsed.title }
                if feed.siteURL == nil { feed.siteURL = parsed.siteURL }
                if feed.faviconURL == nil { feed.faviconURL = parsed.faviconURL }
            } catch {
                hasFailure = true
                lastError = "\(feed.title): \(error.localizedDescription)"
            }
        }

        if selectedFeed != nil && hasFailure {
            errorMessage = lastError
        }
        try? modelContext.save()
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FilterBar — Barra de filtros con colores adaptables a Claro / Oscuro
// ──────────────────────────────────────────────────────────────────────────────
struct FilterBar: View {
    @Binding var selectedFilter: ArticleFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ArticleFilter.allCases) { f in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedFilter = f
                    }
                } label: {
                    HStack(spacing: 4) {
                        if f == .unread {
                            Image(systemName: "envelope.badge")
                                .font(.caption2)
                        } else if f == .favorites {
                            Image(systemName: "star")
                                .font(.caption2)
                        }
                        Text(f.rawValue)
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        selectedFilter == f
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .foregroundStyle(
                        selectedFilter == f
                            ? Color.accentColor
                            : Color.secondary
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// ErrorBannerView
// ──────────────────────────────────────────────────────────────────────────────
private struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).font(.caption).foregroundStyle(Color.primary)
            Spacer()
            Button("Cerrar", action: onDismiss).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
