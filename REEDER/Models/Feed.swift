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
        url.contains("youtube.com/feeds/videos.xml")
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
