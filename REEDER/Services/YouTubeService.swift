import Foundation

// ──────────────────────────────────────────────────────────────────────────────
// YouTubeService — Resolver URLs y handles de YouTube a feeds RSS oficiales
// ──────────────────────────────────────────────────────────────────────────────

actor YouTubeService {

    static let shared = YouTubeService()
    private init() {}

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    /// Detecta si una cadena o URL corresponde a YouTube
    nonisolated func isYouTubeQuery(_ query: String) -> Bool {
        Self.isYouTubeQuery(query)
    }

    static func isYouTubeQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("@") ||
               trimmed.contains("youtube.com") ||
               trimmed.contains("youtu.be")
    }

    /// Extrae el ID del video de YouTube a partir de una URL
    static func extractVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }

        // Caso 1: youtu.be/VIDEO_ID
        if url.host?.contains("youtu.be") == true {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !path.isEmpty { return path }
        }

        // Caso 2: youtube.com/watch?v=VIDEO_ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let vItem = queryItems.first(where: { $0.name == "v" }) {
            return vItem.value
        }

        // Caso 3: youtube.com/shorts/VIDEO_ID o youtube.com/embed/VIDEO_ID
        let pathComponents = url.pathComponents
        if let index = pathComponents.firstIndex(where: { $0 == "shorts" || $0 == "embed" }),
           index + 1 < pathComponents.count {
            return pathComponents[index + 1]
        }

        return nil
    }

    /// Resuelve una entrada del usuario a la URL del feed RSS oficial de YouTube
    func resolveToRSS(query: String) async -> String? {
        var trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Si ya es una URL de feed RSS de YouTube
        if trimmed.contains("youtube.com/feeds/videos.xml") {
            if let corrected = SuggestedYouTubeChannel.correctURL(for: trimmed) {
                return corrected
            }
            return trimmed
        }

        // 1.1 Si coincide con un canal popular conocido
        if let known = SuggestedYouTubeChannel.findChannel(named: trimmed) {
            return known.rssURL
        }

        // 2. Si es una URL con channel_id directo: youtube.com/channel/UC...
        if let channelID = extractChannelIDFromURL(trimmed) {
            return "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)"
        }

        // 3. Si es una playlist: youtube.com/playlist?list=PL...
        if let playlistID = extractPlaylistIDFromURL(trimmed) {
            return "https://www.youtube.com/feeds/videos.xml?playlist_id=\(playlistID)"
        }

        // 4. Si es un handle o URL con @ (ej. @mkbhd, https://www.youtube.com/@midudev)
        var lookupURLString: String? = nil
        if trimmed.hasPrefix("@") {
            lookupURLString = "https://www.youtube.com/\(trimmed)"
        } else if trimmed.contains("youtube.com/@") {
            if !trimmed.hasPrefix("http") { trimmed = "https://" + trimmed }
            lookupURLString = trimmed
        } else if trimmed.contains("youtube.com/c/") || trimmed.contains("youtube.com/user/") {
            if !trimmed.hasPrefix("http") { trimmed = "https://" + trimmed }
            lookupURLString = trimmed
        } else if trimmed.contains("youtube.com/watch") || trimmed.contains("youtu.be/") {
            if !trimmed.hasPrefix("http") { trimmed = "https://" + trimmed }
            lookupURLString = trimmed
        }

        guard let target = lookupURLString, let url = URL(string: target) else {
            return nil
        }

        // Obtener el HTML de la página y buscar el channelId o feed RSS
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9", forHTTPHeaderField: "Accept")

            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            if let channelID = extractChannelIDFromHTML(html) {
                return "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)"
            }
        } catch {
            return nil
        }

        return nil
    }

    private func extractChannelIDFromURL(_ urlString: String) -> String? {
        if let url = URL(string: urlString) {
            let pathComponents = url.pathComponents
            if let index = pathComponents.firstIndex(of: "channel"), index + 1 < pathComponents.count {
                return pathComponents[index + 1]
            }
        }
        return nil
    }

    private func extractPlaylistIDFromURL(_ urlString: String) -> String? {
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let listItem = queryItems.first(where: { $0.name == "list" }) {
            return listItem.value
        }
        return nil
    }

    private func extractChannelIDFromHTML(_ html: String) -> String? {
        // Patrón 1: <link rel="alternate" type="application/rss+xml" title="RSS" href="https://www.youtube.com/feeds/videos.xml?channel_id=UC...">
        if let range = html.range(of: "youtube.com/feeds/videos.xml?channel_id=") {
            let sub = html[range.upperBound...]
            let channelID = sub.prefix(while: { $0 != "\"" && $0 != "'" && $0 != "&" && !$0.isWhitespace })
            if !channelID.isEmpty { return String(channelID) }
        }

        // Patrón 2: <meta itemprop="channelId" content="UC...">
        if let range = html.range(of: "itemprop=\"channelId\" content=\"") {
            let sub = html[range.upperBound...]
            let channelID = sub.prefix(while: { $0 != "\"" })
            if !channelID.isEmpty { return String(channelID) }
        }

        // Patrón 3: "channelId":"UC..."
        if let range = html.range(of: "\"channelId\":\"") {
            let sub = html[range.upperBound...]
            let channelID = sub.prefix(while: { $0 != "\"" })
            if channelID.hasPrefix("UC") { return String(channelID) }
        }

        // Patrón 4: "browse_id":"UC..."
        if let range = html.range(of: "\"browse_id\":\"") {
            let sub = html[range.upperBound...]
            let channelID = sub.prefix(while: { $0 != "\"" })
            if channelID.hasPrefix("UC") { return String(channelID) }
        }

        return nil
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SuggestedYouTubeChannel — Canales populares recomendados en español e inglés
// ──────────────────────────────────────────────────────────────────────────────

struct SuggestedYouTubeChannel: Identifiable {
    let id: String
    let name: String
    let handle: String
    let category: String
    let channelID: String
    let avatarURL: String?

    var rssURL: String {
        "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)"
    }

    /// Mapeo de IDs anteriores erróneos a los IDs oficiales y vigentes de YouTube
    static let legacyBadIDsMap: [String: String] = [
        "UCBJycsmduP4tOGTO55xgo1w": "UCBJycsmduvYEL83R_U4JriQ", // Marques Brownlee
        "UCwB1xJzsPeH9QJ8YlEPe1jw": "UCutHHoZ4kzZFM2LCiZR_dVA", // En Pocas Palabras
        "UCrBZrh8qP_2yoxnpB_qK7bg": "UC36xmz34q02JYaZYKrMwXng", // Nate Gentile
        "UCE_M837H83WVDUm5t5I0iCw": "UCE_M8A5yxnLfW0KghEeajjw", // Apple
        "UC55-mxUj5Nj3niXFReG449A": "UC55-mxUj5Nj3niXFReG44OQ", // Platzi
    ]

    /// Corrige automáticamente una URL de feed de YouTube si tiene un ID desactualizado o erróneo
    static func correctURL(for urlString: String) -> String? {
        for (badID, goodID) in legacyBadIDsMap {
            if urlString.contains(badID) {
                return urlString.replacingOccurrences(of: badID, with: goodID)
            }
        }
        return nil
    }

    /// Busca un canal sugerido por nombre o handle aproximado
    static func findChannel(named query: String) -> SuggestedYouTubeChannel? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        return popular.first { channel in
            channel.name.lowercased() == q ||
            channel.handle.lowercased() == q ||
            channel.handle.lowercased().replacingOccurrences(of: "@", with: "") == q ||
            q.contains(channel.name.lowercased())
        }
    }

    static let popular: [SuggestedYouTubeChannel] = [
        SuggestedYouTubeChannel(
            id: "mkbhd",
            name: "Marques Brownlee",
            handle: "@mkbhd",
            category: "Tecnología",
            channelID: "UCBJycsmduvYEL83R_U4JriQ",
            avatarURL: "https://yt3.googleusercontent.com/lkH37D712tiyphnu0Id0D5MwwQ7IRuwgQLVD05iMXlDWO-kDHqqd8EM5Cs29cGgg-t9GJwV5g=s176-c-k-c0x00ffffff-no-rj"
        ),
        SuggestedYouTubeChannel(
            id: "midudev",
            name: "midudev",
            handle: "@midudev",
            category: "Programación",
            channelID: "UC8LeXCWOalN8SxlrPcG-PaQ",
            avatarURL: "https://yt3.googleusercontent.com/ytc/AIdro_kY9_K7V7Z5kK1p_Gj9-P1Q5e5yMvQ=s176-c-k-c0x00ffffff-no-rj"
        ),
        SuggestedYouTubeChannel(
            id: "dotcsv",
            name: "Dot CSV",
            handle: "@DotCSV",
            category: "Inteligencia Artificial",
            channelID: "UCy5znSnfMsDwaLlROnZ7Qbg",
            avatarURL: "https://yt3.googleusercontent.com/ytc/AIdro_m9D7j9l-8v4uY=s176-c-k-c0x00ffffff-no-rj"
        ),
        SuggestedYouTubeChannel(
            id: "kurzgesagt_es",
            name: "En Pocas Palabras",
            handle: "@EnPocasPalabras",
            category: "Ciencia",
            channelID: "UCutHHoZ4kzZFM2LCiZR_dVA",
            avatarURL: "https://yt3.googleusercontent.com/ytc/AIdro_n8-7=s176-c-k-c0x00ffffff-no-rj"
        ),
        SuggestedYouTubeChannel(
            id: "verge",
            name: "The Verge",
            handle: "@theverge",
            category: "Tecnología",
            channelID: "UCddiUEpeqJcYeBxX1IVBKvQ",
            avatarURL: nil
        ),
        SuggestedYouTubeChannel(
            id: "nategentile",
            name: "Nate Gentile",
            handle: "@NateGentile7",
            category: "Hardware",
            channelID: "UC36xmz34q02JYaZYKrMwXng",
            avatarURL: nil
        ),
        SuggestedYouTubeChannel(
            id: "apple",
            name: "Apple",
            handle: "@Apple",
            category: "Tecnología",
            channelID: "UCE_M8A5yxnLfW0KghEeajjw",
            avatarURL: nil
        ),
        SuggestedYouTubeChannel(
            id: "platzi",
            name: "Platzi",
            handle: "@platzi",
            category: "Educación",
            channelID: "UC55-mxUj5Nj3niXFReG44OQ",
            avatarURL: nil
        )
    ]
}
