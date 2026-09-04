import Foundation

// ──────────────────────────────────────────────────────────────────────────────
// PodcastService — Búsqueda en el directorio de Apple Podcasts y resolución de feeds
// ──────────────────────────────────────────────────────────────────────────────

actor PodcastService {

    static let shared = PodcastService()
    private init() {}

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    /// Busca podcasts por nombre en el directorio oficial de Apple Podcasts (iTunes API)
    func searchPodcasts(query: String) async -> [PodcastSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=podcast&limit=12&lang=es_es")
        else {
            return []
        }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            return response.results.compactMap { item in
                guard let feedURL = item.feedUrl, !feedURL.isEmpty else { return nil }
                return PodcastSearchResult(
                    id: String(item.collectionId ?? 0),
                    title: item.collectionName ?? item.trackName ?? "Podcast",
                    artist: item.artistName ?? "Varios autores",
                    feedURL: feedURL,
                    artworkURL: item.artworkUrl600 ?? item.artworkUrl100,
                    genre: item.primaryGenreName ?? "Podcast"
                )
            }
        } catch {
            return []
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Modelos de respuesta de iTunes Search API
// ──────────────────────────────────────────────────────────────────────────────

private struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesPodcastItem]
}

private struct ITunesPodcastItem: Decodable {
    let collectionId: Int?
    let collectionName: String?
    let trackName: String?
    let artistName: String?
    let feedUrl: String?
    let artworkUrl100: String?
    let artworkUrl600: String?
    let primaryGenreName: String?
}

// ──────────────────────────────────────────────────────────────────────────────
// PodcastSearchResult — Resultado público para la UI
// ──────────────────────────────────────────────────────────────────────────────

struct PodcastSearchResult: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let feedURL: String
    let artworkURL: String?
    let genre: String
}

// ──────────────────────────────────────────────────────────────────────────────
// SuggestedPodcast — Catálogo de podcasts populares recomendados
// ──────────────────────────────────────────────────────────────────────────────

struct SuggestedPodcast: Identifiable {
    let id: String
    let title: String
    let host: String
    let category: String
    let feedURL: String
    let artworkURL: String?

    /// Mapeo de URLs antiguas de podcasts que fueron discontinuadas o cambiaron de hosting
    static let legacyBadURLsMap: [String: String] = [
        "https://www.ivoox.com/the-wild-project_fg_f1883587_filtro_1.xml": "https://anchor.fm/s/115a4336c/podcast/rss",
        "https://anchor.fm/s/b84bb88/podcast/rss": "https://feeds.simplecast.com/xE9e0As4",
        "https://www.ivoox.com/aprendemos-juntos-2030-audio_fg_f11656004_filtro_1.xml": "https://rss.libsyn.com/shows/109232/destinations/631374.xml",
        "https://anchor.fm/s/1e88cf8c/podcast/rss": "https://anchor.fm/s/e80ff06c/podcast/rss"
    ]

    /// Corrige automáticamente una URL de podcast si corresponde a una rota conocida
    static func correctURL(for urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacyBadURLsMap[trimmed]
    }

    static let popular: [SuggestedPodcast] = [
        SuggestedPodcast(
            id: "wildproject",
            title: "The Wild Project",
            host: "Jordi Wild",
            category: "Entrevistas & Charlas",
            feedURL: "https://anchor.fm/s/115a4336c/podcast/rss",
            artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Podcasts126/v4/f9/d1/5f/f9d15fa3-7cf2-110e-647d-c7966f292cff/mza_3972999760339797846.jpg/600x600bb.jpg"
        ),
        SuggestedPodcast(
            id: "radioambulante",
            title: "Radio Ambulante",
            host: "NPR & Daniel Alarcón",
            category: "Historias & Crónicas",
            feedURL: "https://feeds.npr.org/510315/podcast.xml",
            artworkURL: "https://media.npr.org/assets/img/2022/09/16/radio-ambulante-podcast-tile_sq-d60ee48b0a99ff1e7c53d085fc5ba86ca3e6d15b.jpg"
        ),
        SuggestedPodcast(
            id: "hubermanlab",
            title: "Huberman Lab",
            host: "Andrew Huberman",
            category: "Ciencia & Salud",
            feedURL: "https://feeds.megaphone.fm/hubermanlab",
            artworkURL: "https://megaphone.imgix.net/podcasts/4bb8354c-28be-11ec-88c9-03f6f1c4dfeb/image/HL_Logo_Square_3000x3000px_RGB.jpg"
        ),
        SuggestedPodcast(
            id: "thedaily",
            title: "The Daily",
            host: "The New York Times",
            category: "Noticias Globales",
            feedURL: "https://feeds.simplecast.com/54nAGcIl",
            artworkURL: "https://image.simplecastcdn.com/images/005e8dae-f38b-49d9-bbec-9d62fd56c879/11b15c92-b0a4-4a4b-8468-b78995fc07a9/3000x3000/1588624177/artwork.jpg"
        ),
        SuggestedPodcast(
            id: "cotorrisa",
            title: "La Cotorrisa",
            host: "Ricardo Pérez y Slobotzky",
            category: "Comedia",
            feedURL: "https://feeds.simplecast.com/xE9e0As4",
            artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Podcasts221/v4/60/ec/9a/60ec9a66-b29d-ab08-f257-be1a69ba4cc5/mza_14695168599780731050.jpeg/600x600bb.jpg"
        ),
        SuggestedPodcast(
            id: "bbva_aprendemos",
            title: "Aprendemos Juntos 2030",
            host: "BBVA",
            category: "Educación & Sociedad",
            feedURL: "https://rss.libsyn.com/shows/109232/destinations/631374.xml",
            artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Podcasts211/v4/ef/fb/e9/effbe942-6e4b-804c-aea8-5e35f620165f/mza_10970221328492062838.jpg/600x600bb.jpg"
        ),
        SuggestedPodcast(
            id: "platzi_podcast",
            title: "Platzi Podcast",
            host: "Freddy Vega & Platzi",
            category: "Tecnología & Startups",
            feedURL: "https://anchor.fm/s/e80ff06c/podcast/rss",
            artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Podcasts116/v4/9f/bd/e5/9fbde556-08e4-6c9d-7ed8-01e4364d7907/mza_4715463929810317488.jpg/600x600bb.jpg"
        ),
        SuggestedPodcast(
            id: "syntaxfm",
            title: "Syntax - Tasty Web Development",
            host: "Wes Bos & Scott Tolinski",
            category: "Desarrollo Web",
            feedURL: "https://feed.syntax.fm",
            artworkURL: nil
        )
    ]
}
