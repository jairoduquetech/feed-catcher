import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID
    var title: String
    var articleURL: String
    var summary: String?
    var content: String?
    var imageURL: String?       // Featured/thumbnail image from feed
    var author: String?         // Author name (e.g. Alberto Millán)
    var publishDate: Date?
    var isRead: Bool
    var isFavorite: Bool
    var feed: Feed?

    init(title: String,
         articleURL: String,
         summary: String? = nil,
         content: String? = nil,
         imageURL: String? = nil,
         author: String? = nil,
         publishDate: Date? = nil,
         feed: Feed? = nil) {
        self.id = UUID()
        self.title = title
        self.articleURL = articleURL
        self.summary = summary
        self.content = content
        self.imageURL = imageURL
        self.author = author
        self.publishDate = publishDate
        self.isRead = false
        self.isFavorite = false
        self.feed = feed
    }

    /// Extrae el ID del video si el artículo proviene de YouTube
    var youtubeVideoID: String? {
        YouTubeService.extractVideoID(from: articleURL)
    }

    /// Determina si este artículo es un video de YouTube
    var isYouTubeVideo: Bool {
        if youtubeVideoID != nil { return true }
        if let feedURL = feed?.url, feedURL.contains("youtube.com/feeds/videos.xml") { return true }
        return articleURL.contains("youtube.com/watch") || articleURL.contains("youtu.be/")
    }
}
