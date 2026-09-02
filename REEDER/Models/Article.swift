import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID
    var title: String
    var articleURL: String
    var summary: String?
    var content: String?
    var imageURL: String?       // Featured/thumbnail image from feed or podcast artwork
    var author: String?         // Author name or Podcast host
    var publishDate: Date?
    var isRead: Bool
    var isFavorite: Bool
    var audioURL: String?       // Podcast MP3/M4A streaming URL
    var duration: String?       // e.g. "45:12" or "1:12:00"
    var feed: Feed?

    init(title: String,
         articleURL: String,
         summary: String? = nil,
         content: String? = nil,
         imageURL: String? = nil,
         author: String? = nil,
         publishDate: Date? = nil,
         audioURL: String? = nil,
         duration: String? = nil,
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
        self.audioURL = audioURL
        self.duration = duration
        self.feed = feed
    }

    /// Extrae el ID del video si el artículo proviene de YouTube
    var youtubeVideoID: String? {
        YouTubeService.extractVideoID(from: articleURL)
    }

    /// Determina si este artículo es un video de YouTube
    var isYouTubeVideo: Bool {
        if youtubeVideoID != nil { return true }
        if let feedURL = feed?.url, feedURL.contains("youtube.com") { return true }
        return articleURL.contains("youtube.com/watch") || articleURL.contains("youtu.be/")
    }

    /// Determina si este artículo es un episodio de podcast
    var isPodcastEpisode: Bool {
        if let audio = audioURL, !audio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let feedURL = feed?.url.lowercased() {
            if feedURL.contains("ivoox.com") || feedURL.contains("simplecast.com") ||
               feedURL.contains("anchor.fm") || feedURL.contains("megaphone.fm") ||
               feedURL.contains("npr.org") || feedURL.contains("podcast") ||
               feedURL.contains("feed.syntax.fm") {
                return true
            }
        }
        return false
    }

    /// Determina si es un artículo de lectura regular
    var isRegularArticle: Bool {
        !isYouTubeVideo && !isPodcastEpisode
    }
}
