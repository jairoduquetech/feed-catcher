import SwiftUI
import WebKit

// ──────────────────────────────────────────────────────────────────────────────
// ArticleDetailView v6 (Adaptable a Modo Claro/Oscuro + Lector Dinámico)
// ──────────────────────────────────────────────────────────────────────────────

struct ArticleDetailView: View {
    @Bindable var article: Article
    @State private var settings = AppSettings.shared
    @State private var viewMode: ReaderViewMode = .rss

    enum ReaderViewMode { case rss, web }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Cabecera estilo Reeder ───────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {

                    // 1. Fecha en mayúsculas
                    if let date = article.publishDate {
                        Text(date.reederHeaderDateFormatted)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                    }

                    // 2. Título principal
                    Text(article.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    // 3. Autor y Fuente
                    VStack(alignment: .leading, spacing: 2) {
                        if let author = article.author, !author.isEmpty {
                            Text(author.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Color.primary.opacity(0.7))
                                .tracking(0.5)
                        }

                        if let feedTitle = article.feed?.title {
                            HStack(spacing: 5) {
                                FaviconView(url: article.feed?.resolvedFaviconURL, size: 14)
                                Text(feedTitle.uppercased())
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                                    .tracking(0.5)
                            }
                        }
                    }
                    .padding(.top, 2)

                    // 4. Selector de modo de lectura
                    HStack(spacing: 6) {
                        ReaderTabButton(title: "Vista Lector", icon: "doc.plaintext", active: viewMode == .rss) {
                            viewMode = .rss
                        }
                        ReaderTabButton(title: "Web Original", icon: "safari", active: viewMode == .web) {
                            viewMode = .web
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider()

                // ── Cuerpo de la noticia ─────────────────────────────────────
                switch viewMode {
                case .rss:
                    rssContent
                case .web:
                    webContent
                }
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar { toolbarItems }
        .onAppear {
            if !article.isRead { article.isRead = true }
        }
    }

    // MARK: - Contenido Lector (HTML con estilos adaptables a Claro / Oscuro)

    @ViewBuilder
    private var rssContent: some View {
        if let videoID = article.youtubeVideoID {
            YouTubeArticleDetailView(article: article, videoID: videoID, settings: settings)
        } else if let html = article.content, !html.isEmpty {
            ReaderWebView(
                html: html,
                baseURLString: article.articleURL,
                fontFamily: settings.fontFamily.cssValue,
                fontSize: settings.fontSize,
                colorScheme: settings.colorScheme
            )
            .frame(minHeight: 600)
        } else if let summary = article.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                if let img = article.imageURL, !img.isEmpty {
                    CachedAsyncImageView(urlString: img) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 200)
                    }
                }

                Text(summary)
                    .font(.system(size: CGFloat(settings.fontSize)))
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .lineSpacing(8)
                    .textSelection(.enabled)

                Button {
                    viewMode = .web
                } label: {
                    Label("Cargar artículo completo de la web", systemImage: "arrow.down.doc")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.3))
                Text("No hay texto en el feed RSS")
                    .foregroundStyle(.secondary)
                Button("Ver en la web") { viewMode = .web }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var webContent: some View {
        FullArticleWebView(
            urlString: article.articleURL,
            fontFamily: settings.fontFamily.cssValue,
            fontSize: settings.fontSize,
            colorScheme: settings.colorScheme
        )
        .frame(minHeight: 700)
    }

    // MARK: - Barra de herramientas superior

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                article.isRead.toggle()
            } label: {
                Image(systemName: article.isRead ? "circle" : "circle.fill")
                    .foregroundStyle(article.isRead ? Color.secondary : Color.accentColor)
            }
            .help(article.isRead ? "Marcar como no leído" : "Marcar como leído")

            Button {
                article.isFavorite.toggle()
            } label: {
                Image(systemName: article.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(article.isFavorite ? Color.accentColor : Color.secondary)
            }
            .help(article.isFavorite ? "Quitar de favoritos" : "Guardar en favoritos")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(article.articleURL, forType: .string)
            } label: {
                Image(systemName: "link")
                    .foregroundStyle(Color.secondary)
            }
            .help("Copiar enlace del artículo")

            Button {
                if let url = URL(string: article.articleURL) { NSWorkspace.shared.open(url) }
            } label: {
                Image(systemName: "safari")
                    .foregroundStyle(Color.secondary)
            }
            .help("Abrir en Safari")

            ShareLink(item: URL(string: article.articleURL) ?? URL(fileURLWithPath: "")) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.secondary)
            }
            .help("Compartir")
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// ReaderTabButton
// ──────────────────────────────────────────────────────────────────────────────
private struct ReaderTabButton: View {
    let title: String
    let icon: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(active ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(active ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// ReaderWebView — Adaptable a temas Claro y Oscuro
// ──────────────────────────────────────────────────────────────────────────────
struct ReaderWebView: NSViewRepresentable {
    let html: String
    var baseURLString: String = ""
    var fontFamily: String = "-apple-system, BlinkMacSystemFont, sans-serif"
    var fontSize: Double = 17
    var colorScheme: AppColorScheme = .system

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: makeConfig())
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        let baseURL = URL(string: baseURLString)
        wv.loadHTMLString(wrappedHTML, baseURL: baseURL)
    }

    private func makeConfig() -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []
        return cfg
    }

    private var wrappedHTML: String {
        """
        <!DOCTYPE html>
        <html lang="es" data-theme="\(colorScheme.rawValue.lowercased())">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(adaptiveReaderCSS)
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }

    private var adaptiveReaderCSS: String {
        """
        :root {
            --bg-color: transparent;
            --text-color: #1d1d1f;
            --text-strong: #000000;
            --muted-color: rgba(0, 0, 0, 0.5);
            --link-color: #d97706;
            --border-color: rgba(0, 0, 0, 0.1);
            --quote-bg: rgba(0, 0, 0, 0.03);
            --code-bg: rgba(0, 0, 0, 0.05);
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --text-color: rgba(255, 255, 255, 0.86);
                --text-strong: #ffffff;
                --muted-color: rgba(255, 255, 255, 0.45);
                --link-color: #ffc600;
                --border-color: rgba(255, 255, 255, 0.1);
                --quote-bg: rgba(255, 255, 255, 0.04);
                --code-bg: rgba(255, 255, 255, 0.08);
            }
        }

        html[data-theme="claro"] {
            --text-color: #1d1d1f;
            --text-strong: #000000;
            --muted-color: rgba(0, 0, 0, 0.5);
            --link-color: #d97706;
            --border-color: rgba(0, 0, 0, 0.1);
            --quote-bg: rgba(0, 0, 0, 0.03);
            --code-bg: rgba(0, 0, 0, 0.05);
        }

        html[data-theme="oscuro"] {
            --text-color: rgba(255, 255, 255, 0.86);
            --text-strong: #ffffff;
            --muted-color: rgba(255, 255, 255, 0.45);
            --link-color: #ffc600;
            --border-color: rgba(255, 255, 255, 0.1);
            --quote-bg: rgba(255, 255, 255, 0.04);
            --code-bg: rgba(255, 255, 255, 0.08);
        }

        * { box-sizing: border-box; }

        body {
            font-family: \(fontFamily);
            font-size: \(Int(fontSize))px;
            line-height: 1.75;
            color: var(--text-color);
            background: var(--bg-color);
            margin: 0 auto;
            padding: 24px 32px 100px 32px;
            max-width: 720px;
            -webkit-font-smoothing: antialiased;
        }

        p { margin: 0 0 1.3em 0; letter-spacing: -0.01em; }
        strong, b { color: var(--text-strong); font-weight: 700; }

        h1, h2, h3, h4, h5, h6 {
            color: var(--text-strong);
            line-height: 1.3;
            margin: 1.6em 0 0.6em 0;
            font-weight: 700;
            letter-spacing: -0.02em;
        }
        h1 { font-size: 1.6em; }
        h2 { font-size: 1.35em; }
        h3 { font-size: 1.15em; }

        a {
            color: var(--link-color);
            text-decoration: none;
            border-bottom: 1px solid var(--link-color);
        }
        a:hover { border-bottom-width: 2px; }

        img, video, iframe {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 20px auto;
            display: block;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }
        figure { margin: 24px 0; text-align: center; }
        figcaption {
            font-size: 0.8em;
            color: var(--muted-color);
            text-align: center;
            margin-top: 8px;
        }

        blockquote {
            margin: 24px 0;
            padding: 12px 20px;
            border-left: 3px solid var(--link-color);
            background: var(--quote-bg);
            border-radius: 0 8px 8px 0;
            color: var(--text-color);
            font-style: italic;
        }
        blockquote p:last-child { margin-bottom: 0; }

        code {
            font-family: "SF Mono", Menlo, monospace;
            font-size: 0.88em;
            background: var(--code-bg);
            border-radius: 4px;
            padding: 2px 6px;
        }
        pre {
            background: var(--code-bg);
            border-radius: 8px;
            padding: 16px;
            overflow-x: auto;
            margin: 20px 0;
            border: 1px solid var(--border-color);
        }
        pre code { background: none; padding: 0; }

        ul, ol { padding-left: 1.6em; margin: 1em 0 1.4em 0; }
        li { margin: 0.4em 0; }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            font-size: 0.9em;
        }
        th, td {
            padding: 10px 14px;
            border: 1px solid var(--border-color);
            text-align: left;
        }
        th { background: var(--code-bg); font-weight: 600; }

        hr {
            border: none;
            border-top: 1px solid var(--border-color);
            margin: 32px 0;
        }

        script, style, iframe[src*="ads"], .ad, .advertisement,
        .social-share, .newsletter-signup, .cookie-banner,
        [class*="promo"], [class*="popup"], [id*="popup"] {
            display: none !important;
        }
        """
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FullArticleWebView
// ──────────────────────────────────────────────────────────────────────────────
struct FullArticleWebView: NSViewRepresentable {
    let urlString: String
    var fontFamily: String = "-apple-system, BlinkMacSystemFont, sans-serif"
    var fontSize: Double = 17
    var colorScheme: AppColorScheme = .system

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []

        let script = WKUserScript(
            source: readerScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        cfg.userContentController.addUserScript(script)

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.setValue(false, forKey: "drawsBackground")
        wv.allowsLinkPreview = true
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        if wv.url == nil {
            wv.load(URLRequest(url: url))
        }
    }

    private var readerScript: String {
        """
        (function() {
            var style = document.createElement('style');
            style.textContent = `
                @media (prefers-color-scheme: dark) {
                    html, body { background: #1c1c1e !important; color: rgba(255,255,255,0.85) !important; }
                    a { color: #ffc600 !important; }
                    h1, h2, h3, h4 { color: #ffffff !important; }
                }
                @media (prefers-color-scheme: light) {
                    html, body { background: #ffffff !important; color: #1d1d1f !important; }
                    a { color: #d97706 !important; }
                    h1, h2, h3, h4 { color: #000000 !important; }
                }
                body {
                    font-family: \(fontFamily) !important;
                    font-size: \(Int(fontSize))px !important;
                    line-height: 1.75 !important;
                    max-width: 740px !important;
                    margin: 0 auto !important;
                    padding: 24px 32px !important;
                }
                img { max-width: 100% !important; height: auto !important; border-radius: 8px !important; margin: 16px auto !important; display: block !important; }
                header, nav, footer, aside, [class*="sidebar"],
                [class*="header"], [class*="footer"], [class*="nav"],
                [class*="menu"], [class*="banner"], [class*="cookie"],
                [class*="newsletter"], [class*="subscribe"], [class*="popup"],
                [class*="ad-"], [class*="-ad"], [id*="ad-"],
                .ad, .ads, .advertisement, .social { display: none !important; }
            `;
            document.head.appendChild(style);
        })();
        """
    }
}

// MARK: - Formato de fecha para cabecera estilo Reeder
extension Date {
    var reederHeaderDateFormatted: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "EEEE, d 'DE' MMMM 'DE' yyyy 'A LAS' HH:mm"
        return df.string(from: self).uppercased()
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// YouTubeArticleDetailView — Reproductor de video y descripción de YouTube
// ──────────────────────────────────────────────────────────────────────────────
private struct YouTubeArticleDetailView: View {
    let article: Article
    let videoID: String
    let settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Reproductor de YouTube embebido (16:9)
            YouTubePlayerWebView(videoID: videoID)
                .frame(minHeight: 440)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)

            // Barra de acciones del video
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Ver en YouTube", systemImage: "play.rectangle.fill")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("https://www.youtube.com/watch?v=\(videoID)", forType: .string)
                } label: {
                    Label("Copiar enlace", systemImage: "link")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)

            // Descripción del video
            if let desc = article.summary ?? article.content, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPCIÓN DEL VIDEO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)

                    Text(desc)
                        .font(.system(size: CGFloat(max(13, settings.fontSize - 1))))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// YouTubePlayerWebView — Embebe el reproductor oficial de YouTube sin cookies
// ──────────────────────────────────────────────────────────────────────────────
struct YouTubePlayerWebView: NSViewRepresentable {
    let videoID: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
          iframe { width: 100%; height: 100%; border: none; }
        </style>
        </head>
        <body>
          <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=0&rel=0&playsinline=1&modestbranding=1" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen" allowfullscreen></iframe>
        </body>
        </html>
        """
        wv.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
    }
}

