import Foundation
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// FeedCategory — Carpeta que agrupa feeds relacionados
// ──────────────────────────────────────────────────────────────────────────────

@Model
final class FeedCategory {
    var id: UUID
    var name: String
    var icon: String          // SF Symbol name, e.g. "gamecontroller", "laptopcomputer"
    var colorHex: String      // Hex color, e.g. "#FF6B6B"
    var sortOrder: Int
    var addedDate: Date

    @Relationship(deleteRule: .nullify, inverse: \Feed.category)
    var feeds: [Feed]

    init(name: String, icon: String = "folder.fill", colorHex: String = "#888888", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.addedDate = Date()
        self.feeds = []
    }

    /// Total de artículos no leídos en todos sus feeds
    var unreadCount: Int {
        feeds.reduce(0) { $0 + $1.articles.filter { !$0.isRead }.count }
    }
}
