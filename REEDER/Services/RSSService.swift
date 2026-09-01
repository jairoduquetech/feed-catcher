import Foundation

// ──────────────────────────────────────────────────────────────────────────────
// RSSService v5
// Full extraction of images, author, summary, content, siteURL, favicon
// ──────────────────────────────────────────────────────────────────────────────

enum RSSError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "La URL del feed no es válida."
        case .networkError(let e): return "Error de red: \(e.localizedDescription)"
        case .httpError(let code): return "El servidor respondió con código HTTP \(code)."
        case .parsingFailed:       return "No se pudo interpretar el contenido del feed."
        }
    }
}

struct ParsedArticle {
    let title: String
    let url: String
    let summary: String?
    let content: String?
    let imageURL: String?
    let author: String?
    let publishDate: Date?
}

struct ParsedFeed {
    let title: String
    let siteURL: String?
    let faviconURL: String?
    let items: [ParsedArticle]
}

// ──────────────────────────────────────────────────────────────────────────────
actor RSSService {

    static let shared = RSSService()
    private init() {}

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    func fetchFeed(urlString: String) async throws -> ParsedFeed {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let initialURL = URL(string: trimmed) else { throw RSSError.invalidURL }

        do {
            return try await performFetch(url: initialURL, sourceURL: trimmed)
        } catch {
            if trimmed.hasPrefix("http://") {
                let secureStr = "https://" + trimmed.dropFirst("http://".count)
                if let secureURL = URL(string: secureStr) {
                    if let result = try? await performFetch(url: secureURL, sourceURL: secureStr) {
                        return result
                    }
                }
            } else if trimmed.hasPrefix("https://") {
                let httpStr = "http://" + trimmed.dropFirst("https://".count)
                if let httpURL = URL(string: httpStr) {
                    if let result = try? await performFetch(url: httpURL, sourceURL: httpStr) {
                        return result
                    }
                }
            }
            throw error
        }
    }

    private func performFetch(url: URL, sourceURL: String) async throws -> ParsedFeed {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("es-ES,es;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RSSError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw RSSError.httpError(http.statusCode)
        }

        return try await Task.detached(priority: .userInitiated) {
            let parser = FeedXMLParser(data: data, sourceURL: sourceURL)
            guard let feed = parser.parse() else { throw RSSError.parsingFailed }
            return feed
        }.value
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FeedXMLParser
// ──────────────────────────────────────────────────────────────────────────────
private final class FeedXMLParser: NSObject, XMLParserDelegate {

    private let data: Data
    private let sourceURL: String

    private var feedTitle = ""
    private var feedSiteURL: String?
    private var items: [ParsedArticle] = []

    private var inItem = false
    private var currentElement = ""
    private var currentQName = ""

    private var itemTitle = ""
    private var itemLink = ""
    private var itemSummary = ""
    private var itemContent = ""
    private var itemImageURL: String?
    private var itemAuthor = ""
    private var itemPubDate = ""
    private var isAtom = false

    private var charBuffer = ""

    init(data: Data, sourceURL: String) {
        self.data = data
        self.sourceURL = sourceURL
    }

    func parse() -> ParsedFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        let ok = parser.parse()
        guard ok || !items.isEmpty else { return nil }

        let base = feedSiteURL ?? sourceURL
        let favicon: String?
        if let host = URL(string: base)?.host {
            favicon = "https://icons.duckduckgo.com/ip3/\(host).ico"
        } else {
            favicon = nil
        }

        return ParsedFeed(
            title: feedTitle.isEmpty ? sourceURL : feedTitle,
            siteURL: feedSiteURL,
            faviconURL: favicon,
            items: items
        )
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attrs: [String: String] = [:]) {

        let local = elementName.lowercased()
        let qualified = (qName ?? elementName).lowercased()
        currentElement = local
        currentQName = qualified
        charBuffer = ""

        if local == "feed" { isAtom = true }

        if local == "item" || local == "entry" {
            inItem = true
            itemTitle = ""; itemLink = ""; itemSummary = ""
            itemContent = ""; itemImageURL = nil; itemAuthor = ""; itemPubDate = ""
            return
        }

        guard inItem else {
            if local == "link" {
                if let href = attrs["href"], !href.isEmpty {
                    feedSiteURL = href
                }
            }
            return
        }

        // Inside item
        if local == "link" {
            let rel = attrs["rel"] ?? "alternate"
            if rel == "alternate" || rel.isEmpty, let href = attrs["href"], !href.isEmpty {
                itemLink = href
            }
            if rel == "enclosure" || attrs["type"]?.hasPrefix("image/") == true {
                if let href = attrs["href"], !href.isEmpty, itemImageURL == nil {
                    itemImageURL = cleanURL(href)
                }
            }
            return
        }

        if qualified.hasSuffix(":thumbnail") || local == "thumbnail" {
            if let u = attrs["url"] ?? attrs["href"], !u.isEmpty, itemImageURL == nil {
                itemImageURL = cleanURL(u)
            }
            return
        }

        if qualified.hasSuffix(":content") && local != "content" {
            let medium = attrs["medium"] ?? ""
            let type   = attrs["type"] ?? ""
            let isImg  = medium == "image" || type.hasPrefix("image/") || medium.isEmpty
            if isImg, let u = attrs["url"] ?? attrs["href"], !u.isEmpty, itemImageURL == nil {
                itemImageURL = cleanURL(u)
            }
            return
        }

        if local == "enclosure" {
            let type = attrs["type"] ?? ""
            let u    = attrs["url"] ?? attrs["href"] ?? ""
            let isImgType = type.hasPrefix("image/") || u.hasSuffix(".jpg") || u.hasSuffix(".jpeg") || u.hasSuffix(".png") || u.hasSuffix(".webp")
            if isImgType, !u.isEmpty, itemImageURL == nil {
                itemImageURL = cleanURL(u)
            }
            return
        }

        if qualified.hasSuffix(":image") || local == "image" {
            if let u = attrs["href"] ?? attrs["url"], !u.isEmpty, itemImageURL == nil {
                itemImageURL = cleanURL(u)
            }
            return
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        charBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        if let s = String(data: data, encoding: .utf8) { charBuffer += s }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {

        let local = elementName.lowercased()
        let qualified = (qName ?? elementName).lowercased()
        let trimmed = charBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { charBuffer = "" }

        if local == "item" || local == "entry" {
            guard !itemTitle.isEmpty, !itemLink.isEmpty else { inItem = false; return }

            let extractedImage = itemImageURL
                ?? extractFirstImage(from: itemContent)
                ?? extractFirstImage(from: itemSummary)

            let article = ParsedArticle(
                title:       itemTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                url:         itemLink,
                summary:     itemSummary.isEmpty ? nil : stripHTML(itemSummary),
                content:     itemContent.isEmpty ? nil : itemContent,
                imageURL:    extractedImage,
                author:      itemAuthor.isEmpty ? nil : itemAuthor,
                publishDate: parseDate(itemPubDate)
            )
            items.append(article)
            inItem = false
            return
        }

        guard !trimmed.isEmpty else { return }

        if inItem {
            switch local {
            case "title":
                itemTitle += trimmed
            case "link":
                if !isAtom && itemLink.isEmpty { itemLink = trimmed }
            case "description", "summary":
                itemSummary += trimmed
            case "content", "encoded":
                itemContent += trimmed
            case "creator", "author", "dc:creator", "name":
                if itemAuthor.isEmpty { itemAuthor = trimmed }
            case "pubdate", "published", "updated", "date", "dc:date":
                itemPubDate += trimmed
            case "guid", "id":
                if itemLink.isEmpty, trimmed.hasPrefix("http") { itemLink = trimmed }
            default:
                if qualified == "dc:creator" && itemAuthor.isEmpty {
                    itemAuthor = trimmed
                }
            }
        } else {
            switch local {
            case "title":
                if feedTitle.isEmpty { feedTitle = trimmed }
            case "link":
                if feedSiteURL == nil, trimmed.hasPrefix("http") { feedSiteURL = trimmed }
            default:
                break
            }
        }
    }

    // MARK: - Extracción de imágenes

    private func extractFirstImage(from html: String) -> String? {
        guard !html.isEmpty else { return nil }

        let unescaped = html
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        let patterns = [
            #"<img[^>]+src=[\"']([^\"']+)[\"']"#,
            #"<img[^>]+src=([^\s>]+)"#,
            #"<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:image[\"']"#,
        ]

        for source in [html, unescaped] {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                    let range = NSRange(source.startIndex..., in: source)
                    if let match = regex.firstMatch(in: source, range: range),
                       match.numberOfRanges > 1,
                       let captureRange = Range(match.range(at: 1), in: source) {
                        let src = String(source[captureRange])
                        if src.hasPrefix("http") && !src.contains("pixel") && !src.contains("tracker") && !src.contains("feedsportal") {
                            return cleanURL(src)
                        }
                    }
                }
            }
        }
        return nil
    }

    private func cleanURL(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Limpieza HTML

    private func stripHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "<[^>]+>",
                                               with: "",
                                               options: .regularExpression)
        result = result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\n",     with: " ")
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fechas

    private func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            df.dateFormat = fmt
            if let date = df.date(from: string) { return date }
        }
        return nil
    }
}
