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
    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article]

    init(title: String, url: String, faviconURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.faviconURL = faviconURL
        self.addedDate = Date()
        self.articles = []
    }

    /// Best-effort favicon URL using DuckDuckGo's favicon service
    var resolvedFaviconURL: String? {
        if let existing = faviconURL, !existing.isEmpty { return existing }
        // Derive domain from siteURL or feed URL
        let base = siteURL ?? url
        guard let host = URL(string: base)?.host else { return nil }
        return "https://icons.duckduckgo.com/ip3/\(host).ico"
    }
}
