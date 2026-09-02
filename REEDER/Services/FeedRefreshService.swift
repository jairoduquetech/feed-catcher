import Foundation
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// FeedRefreshService v4
// Actualización automática en segundo plano con extracción de autor e imágenes
// ──────────────────────────────────────────────────────────────────────────────

@Observable
final class FeedRefreshService {

    static let shared = FeedRefreshService()
    private init() {}

    var isRefreshing = false
    var lastRefreshDate: Date? = nil
    var refreshInterval: TimeInterval = 30 * 60  // 30 minutos por defecto

    private var refreshTask: Task<Void, Never>?

    // MARK: - Ciclo de vida

    func start(modelContainer: ModelContainer) {
        stop()
        refreshTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshAll(modelContainer: modelContainer)
                let steps = Int(await self.refreshInterval)
                for _ in 0..<steps {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func triggerManualRefresh(modelContainer: ModelContainer) {
        Task.detached(priority: .userInitiated) {
            await self.refreshAll(modelContainer: modelContainer)
        }
    }

    // MARK: - Lógica de actualización

    @MainActor
    private func refreshAll(modelContainer: ModelContainer) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshDate = Date()
        }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Feed>()
        guard let feeds = try? context.fetch(descriptor), !feeds.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for feed in feeds {
                group.addTask {
                    await self.refreshFeed(feed, context: context)
                }
            }
        }

        try? context.save()
    }

    private func refreshFeed(_ feed: Feed, context: ModelContext) async {
        guard let parsed = try? await RSSService.shared.fetchFeed(urlString: feed.url) else { return }

        await MainActor.run {
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
                    if existing.audioURL == nil && item.audioURL != nil {
                        existing.audioURL = item.audioURL
                    }
                    if existing.duration == nil && item.duration != nil {
                        existing.duration = item.duration
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
                        audioURL: item.audioURL,
                        duration: item.duration,
                        feed: feed
                    )
                    context.insert(article)
                }
            }

            // Cleanup: mantener el tamaño de la base de datos bajo control
            // Eliminar artículos leídos, no favoritos, y que tengan más de 30 días
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let oldArticles = feed.articles.filter { article in
                article.isRead && !article.isFavorite && (article.publishDate ?? article.feed?.addedDate ?? Date()) < thirtyDaysAgo
            }
            
            for old in oldArticles {
                context.delete(old)
            }
            
            // Si el feed aún tiene muchísimos artículos (ej. más de 200), borrar los más viejos no leídos también
            if feed.articles.count > 300 {
                let excess = feed.articles
                    .filter { !$0.isFavorite }
                    .sorted { ($0.publishDate ?? Date.distantPast) > ($1.publishDate ?? Date.distantPast) }
                    .dropFirst(300)
                
                for old in excess {
                    context.delete(old)
                }
            }
            if feed.title == feed.url || feed.title.isEmpty { feed.title = parsed.title }
            if feed.siteURL == nil { feed.siteURL = parsed.siteURL }
            if feed.faviconURL == nil { feed.faviconURL = parsed.faviconURL }
        }
    }
}
