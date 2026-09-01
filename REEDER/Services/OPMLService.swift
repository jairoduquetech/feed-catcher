import Foundation
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// OPMLService
// Handles import and export of OPML 1.0/2.0 feed subscription files.
// Compatible with Reeder 4, NetNewsWire, Feedly, Inoreader, and any
// standard RSS reader that supports OPML.
// ──────────────────────────────────────────────────────────────────────────────

enum OPMLError: LocalizedError {
    case invalidFile
    case noFeedsFound
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile:        return "El archivo no es un OPML válido."
        case .noFeedsFound:       return "No se encontraron feeds en el archivo."
        case .exportFailed(let m): return "Error al exportar: \(m)"
        }
    }
}

// Lightweight struct representing a parsed OPML entry
struct OPMLEntry {
    let title: String
    let xmlURL: String
    let htmlURL: String?
    let folder: String?
}

// ──────────────────────────────────────────────────────────────────────────────
actor OPMLService {

    static let shared = OPMLService()
    private init() {}

    // MARK: - Import

    /// Parses an OPML file at the given URL and returns feed entries.
    func parseOPML(at url: URL) async throws -> [OPMLEntry] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw OPMLError.invalidFile
        }

        return try await Task.detached(priority: .userInitiated) {
            let parser = OPMLXMLParser(data: data)
            let entries = parser.parse()
            if entries.isEmpty { throw OPMLError.noFeedsFound }
            return entries
        }.value
    }

    // MARK: - Export

    /// Generates OPML XML string from a list of Feed models.
    func generateOPML(from feeds: [Feed]) -> String {
        var lines: [String] = []
        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<opml version="2.0">"#)
        lines.append("  <head>")
        lines.append("    <title>REEDER Subscriptions</title>")
        lines.append("    <dateCreated>\(Date().formatted(.iso8601))</dateCreated>")
        lines.append("  </head>")
        lines.append("  <body>")

        for feed in feeds {
            let safeTitle = xmlEscape(feed.title)
            let safeURL   = xmlEscape(feed.url)
            lines.append(
                "    <outline type=\"rss\" text=\"\(safeTitle)\" title=\"\(safeTitle)\" xmlUrl=\"\(safeURL)\"/>"
            )
        }

        lines.append("  </body>")
        lines.append("</opml>")
        return lines.joined(separator: "\n")
    }

    private func xmlEscape(_ str: String) -> String {
        str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// OPMLXMLParser — SAX-style parser for OPML
// ──────────────────────────────────────────────────────────────────────────────
private final class OPMLXMLParser: NSObject, XMLParserDelegate {

    private let data: Data
    private var entries: [OPMLEntry] = []
    private var currentFolder: String? = nil
    private var folderStack: [String] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [OPMLEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attrs: [String: String] = [:]) {

        guard elementName.lowercased() == "outline" else { return }

        let xmlURL = attrs["xmlUrl"] ?? attrs["xmlurl"] ?? attrs["XMLURL"] ?? ""

        if xmlURL.isEmpty {
            // This is a folder/group outline — push to stack
            let folderTitle = attrs["title"] ?? attrs["text"] ?? "Untitled"
            folderStack.append(folderTitle)
            currentFolder = folderTitle
        } else {
            // This is a feed outline
            let title = attrs["title"] ?? attrs["text"] ?? xmlURL
            let htmlURL = attrs["htmlUrl"] ?? attrs["htmlurl"]
            let folder = folderStack.last
            entries.append(OPMLEntry(title: title, xmlURL: xmlURL, htmlURL: htmlURL, folder: folder))
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        guard elementName.lowercased() == "outline" else { return }
        if !folderStack.isEmpty {
            folderStack.removeLast()
            currentFolder = folderStack.last
        }
    }
}
