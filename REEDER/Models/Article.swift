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
}
