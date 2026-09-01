import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// ArticleRowView v6 (Ultra-rápido + Adaptable a Modo Claro/Oscuro)
// Utiliza CachedAsyncImageView con memoria RAM y disco para 120 FPS de scroll.
// ──────────────────────────────────────────────────────────────────────────────

struct ArticleRowView: View {
    let article: Article
    @State private var settings = AppSettings.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {

            // ── 1. Favicon a la izquierda ────────────────────────────────────
            if settings.showFavicons {
                FaviconView(url: article.feed?.resolvedFaviconURL, size: 18)
                    .padding(.top, 2)
            }

            // ── 2. Contenido central (Fuente, Fecha, Título, Resumen) ────────
            VStack(alignment: .leading, spacing: settings.compactRowDensity ? 2 : 4) {

                // Línea superior: Nombre del feed + Hora/Fecha
                HStack(spacing: 4) {
                    if let feedTitle = article.feed?.title {
                        Text(feedTitle.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                            .tracking(0.3)
                    }

                    Spacer(minLength: 4)

                    if let date = article.publishDate {
                        Text(date.reederTimeFormatted)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                // Título de la noticia
                Text(article.title)
                    .font(.system(size: settings.compactRowDensity ? 13 : 13.5, weight: .semibold))
                    .foregroundStyle(article.isRead ? Color.primary.opacity(0.45) : Color.primary)
                    .lineLimit(settings.compactRowDensity ? 1 : 2)
                    .lineSpacing(1.5)
                    .multilineTextAlignment(.leading)

                // Resumen (opcional según ajustes)
                if settings.showSummaries, let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.85))
                        .lineLimit(settings.compactRowDensity ? 1 : 2)
                        .lineSpacing(1.2)
                        .multilineTextAlignment(.leading)
                }
            }

            // ── 3. Miniatura rápida en caché (68x68) ─────────────────────────
            if settings.showThumbnails, let imgURL = article.imageURL, !imgURL.isEmpty {
                CachedAsyncImageView(
                    urlString: imgURL,
                    targetSize: CGSize(width: 68, height: 68)
                ) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity(article.isRead ? 0.6 : 1.0)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 68, height: 68)
                }
                .frame(width: 68, height: 68)
            }
        }
        .padding(.vertical, settings.compactRowDensity ? 5 : 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .opacity(article.isRead ? 0.85 : 1.0)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FaviconView — Icono con caché de alta velocidad
// ──────────────────────────────────────────────────────────────────────────────
struct FaviconView: View {
    let url: String?
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let urlStr = url, !urlStr.isEmpty {
                CachedAsyncImageView(
                    urlString: urlStr,
                    targetSize: CGSize(width: size, height: size)
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } placeholder: {
                    fallbackIcon
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: size * 0.55))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Formato de fecha estilo Reeder
extension Date {
    var reederTimeFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "es_ES")
            df.dateFormat = "h:mm a"
            return df.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Ayer"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: self, relativeTo: Date())
        }
    }
}
