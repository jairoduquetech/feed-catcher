import Foundation
import SwiftData

@Model
final class Feed {
    var id: UUID
    var title: String
    var url: String
    var siteURL: String?       // The HTML website URL (from <link> in RSS)
    var faviconURL: String?    // Resolved favicon URL
    var addedDate: Date
    var category: FeedCategory?   // Carpeta a la que pertenece (nil = sin categoría)

    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article]

    init(title: String, url: String, faviconURL: String? = nil, category: FeedCategory? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.faviconURL = faviconURL
        self.category = category
        self.addedDate = Date()
        self.articles = []
    }

    /// Detecta si es un feed de canal de YouTube
    var isYouTubeFeed: Bool {
        url.contains("youtube.com/feeds/videos.xml") || url.contains("youtube.com")
    }

    /// Detecta si es un feed de podcast
    var isPodcastFeed: Bool {
        if url.contains("ivoox.com") || url.contains("simplecast.com") || url.contains("anchor.fm") || url.contains("megaphone.fm") || url.contains("npr.org") || url.contains("podcast") || url.contains("feed.syntax.fm") {
            return true
        }
        return articles.contains(where: { $0.isPodcastEpisode })
    }

    /// Detecta si es un feed regular de noticias/artículos (no video ni podcast)
    var isRegularArticleFeed: Bool {
        !isYouTubeFeed && !isPodcastFeed
    }

    /// Best-effort favicon URL using DuckDuckGo's favicon service
    var resolvedFaviconURL: String? {
        if let existing = faviconURL, !existing.isEmpty { return existing }
        if isYouTubeFeed {
            return "https://icons.duckduckgo.com/ip3/youtube.com.ico"
        }
        let base = siteURL ?? url
        guard let host = URL(string: base)?.host else { return nil }
        return "https://icons.duckduckgo.com/ip3/\(host).ico"
    }
}
