import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// SidebarItem — Enum para la selección de la barra lateral
// ──────────────────────────────────────────────────────────────────────────────
enum SidebarItem: Hashable, Identifiable {
    case all
    case favorites
    case feed(UUID)

    var id: String {
        switch self {
        case .all: return "all"
        case .favorites: return "favorites"
        case .feed(let id): return id.uuidString
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SidebarView v6 (Adaptable a Modo Claro/Oscuro)
// ──────────────────────────────────────────────────────────────────────────────

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feed.addedDate) private var feeds: [Feed]
    @Binding var selection: SidebarItem
    @Binding var showAddFeed: Bool

    @State private var showImportOPML = false
    @State private var showExportOPML = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess: String?

    init(selection: Binding<SidebarItem>, showAddFeed: Binding<Bool>) {
        self._selection = selection
        self._showAddFeed = showAddFeed
    }

    private var refreshService = FeedRefreshService.shared

    private var totalUnreadCount: Int {
        feeds.reduce(0) { sum, feed in
            sum + feed.articles.filter { !$0.isRead }.count
        }
    }

    var body: some View {
        List(selection: $selection) {

            // ── Vistas Inteligentes ───────────────────────────────────────────
            Section("VISTAS INTELIGENTES") {
                HStack(spacing: 8) {
                    Image(systemName: "tray.2.fill")
                        .foregroundStyle(selection == .all ? Color.accentColor : Color.secondary)
                        .frame(width: 18)
                    Text("Todos los artículos")
                        .foregroundStyle(selection == .all ? Color.primary : Color.primary.opacity(0.85))
                    Spacer()
                    if totalUnreadCount > 0 {
                        Text("\(totalUnreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = .all }
                .tag(SidebarItem.all)

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(selection == .favorites ? Color.yellow : Color.yellow.opacity(0.7))
                        .frame(width: 18)
                    Text("Favoritos")
                        .foregroundStyle(selection == .favorites ? Color.primary : Color.primary.opacity(0.85))
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = .favorites }
                .tag(SidebarItem.favorites)
            }

            // ── Feeds ────────────────────────────────────────────────────────
            if !feeds.isEmpty {
                Section("FEEDS") {
                    ForEach(feeds) { feed in
                        FeedRowView(feed: feed, isSelected: selection == .feed(feed.id))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selection = .feed(feed.id)
                            }
                            .tag(SidebarItem.feed(feed.id))
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteFeed(feed)
                                } label: {
                                    Label("Eliminar feed", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteFeeds)
                }
            }
        }
        .listStyle(.sidebar)
        // ── Barra de herramientas ────────────────────────────────────────────
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if refreshService.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .help("Actualizando feeds…")
                }

                Menu {
                    Button {
                        showImportOPML = true
                    } label: {
                        Label("Importar desde Reeder / OPML…", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportOPML()
                    } label: {
                        Label("Exportar como OPML…", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Importar / Exportar")

                Button {
                    showAddFeed = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Añadir feed")
            }
        }
        .navigationTitle("Feed Catcher")
        .safeAreaInset(edge: .bottom) {
            if let date = refreshService.lastRefreshDate {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text(date.reederTimeFormatted)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(8)
            }
        }
        .fileImporter(
            isPresented: $showImportOPML,
            allowedContentTypes: [.init(filenameExtension: "opml") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleOPMLImport(result: result) }
        }
        .overlay(alignment: .bottom) {
            statusOverlayView
        }
        .animation(.easeInOut, value: isImporting)
        .animation(.easeInOut, value: importSuccess)
        .animation(.easeInOut, value: importError)
    }

    @ViewBuilder
    private var statusOverlayView: some View {
        VStack(spacing: 4) {
            if isImporting {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Importando feeds…").font(.caption)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            if let success = importSuccess {
                Label(success, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            importSuccess = nil
                        }
                    }
            }
            if let error = importError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { importError = nil }
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Acciones

    private func deleteFeed(_ feed: Feed) {
        if selection == .feed(feed.id) {
            selection = .all
        }
        modelContext.delete(feed)
        try? modelContext.save()
    }

    private func deleteFeeds(at offsets: IndexSet) {
        for index in offsets {
            let feed = feeds[index]
            if selection == .feed(feed.id) {
                selection = .all
            }
            modelContext.delete(feed)
        }
        try? modelContext.save()
    }

    // MARK: - Importación OPML

    @MainActor
    private func handleOPMLImport(result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }

            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            isImporting = true
            importError = nil
            importSuccess = nil
            defer { isImporting = false }

            do {
                let entries = try await OPMLService.shared.parseOPML(at: url)
                let existingURLs = Set(feeds.map(\.url))
                var newCount = 0

                for entry in entries where !existingURLs.contains(entry.xmlURL) {
                    let feed = Feed(title: entry.title, url: entry.xmlURL)
                    modelContext.insert(feed)
                    newCount += 1
                }

                try? modelContext.save()
                importSuccess = "\(newCount) feeds importados con éxito"
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    // MARK: - Exportación OPML

    private func exportOPML() {
        let opml = OPMLService.shared.generateOPML(from: Array(feeds))
        guard let data = opml.data(using: .utf8) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "suscripciones-feedcatcher.opml"
        panel.allowedContentTypes = [.xml]
        panel.title = "Exportar suscripciones como OPML"
        panel.message = "Elige dónde guardar tus suscripciones"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FeedRowView — Fila de feed con favicon y contador
// ──────────────────────────────────────────────────────────────────────────────
private struct FeedRowView: View {
    let feed: Feed
    var isSelected: Bool = false

    var unreadCount: Int {
        feed.articles.filter { !$0.isRead }.count
    }

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(url: feed.resolvedFaviconURL, size: 16)

            Text(feed.title)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(unreadCount > 0 ? 0.9 : 0.65))
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

            Spacer()

            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .padding(.vertical, 3)
    }
}
