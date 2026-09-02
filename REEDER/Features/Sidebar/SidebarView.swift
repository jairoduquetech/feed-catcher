import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// ──────────────────────────────────────────────────────────────────────────────
// SidebarItem — Enum para la selección de la barra lateral
// ──────────────────────────────────────────────────────────────────────────────
enum SidebarItem: Hashable, Identifiable {
    case all
    case favorites
    case allVideos
    case allPodcasts
    case category(UUID)
    case feed(UUID)

    var id: String {
        switch self {
        case .all:              return "all"
        case .favorites:        return "favorites"
        case .allVideos:        return "all-videos"
        case .allPodcasts:      return "all-podcasts"
        case .category(let id): return "cat-\(id.uuidString)"
        case .feed(let id):     return id.uuidString
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SidebarView v10 — Secciones Exclusivas: Noticias, YouTube y Podcasts
// ──────────────────────────────────────────────────────────────────────────────
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Feed.addedDate) private var feeds: [Feed]
    @Query(sort: \FeedCategory.sortOrder) private var categories: [FeedCategory]
    @Binding var selection: SidebarItem
    @Binding var showAddFeed: Bool

    @State private var showAddCategory = false
    @State private var editingCategory: FeedCategory? = nil
    @State private var showImportOPML = false
    @State private var movingFeed: Feed? = nil
    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var importSuccess: String? = nil
    @State private var collapsedCategories: Set<UUID> = []
    @State private var isUncategorizedTargeted: Bool = false

    init(selection: Binding<SidebarItem>, showAddFeed: Binding<Bool>) {
        self._selection = selection
        self._showAddFeed = showAddFeed
    }

    private var refreshService = FeedRefreshService.shared

    // ── Clasificación de Feeds ───────────────────────────────────────────────

    private var regularFeeds: [Feed] {
        feeds.filter { $0.isRegularArticleFeed }
    }

    private var regularFeedsWithoutCategory: [Feed] {
        regularFeeds.filter { $0.category == nil }
    }

    private var youtubeFeeds: [Feed] {
        feeds.filter { $0.isYouTubeFeed }
    }

    private var podcastFeeds: [Feed] {
        feeds.filter { $0.isPodcastFeed }
    }

    // ── Contadores de No Leídos ─────────────────────────────────────────────

    private var totalArticlesUnreadCount: Int {
        regularFeeds.reduce(0) { sum, feed in
            sum + feed.articles.filter { !$0.isRead }.count
        }
    }

    private var totalYouTubeUnreadCount: Int {
        youtubeFeeds.reduce(0) { sum, feed in
            sum + feed.articles.filter { !$0.isRead }.count
        }
    }

    private var totalPodcastsUnreadCount: Int {
        podcastFeeds.reduce(0) { sum, feed in
            sum + feed.articles.filter { !$0.isRead }.count
        }
    }

    // ── Secciones de la Barra Lateral ────────────────────────────────────────

    @ViewBuilder
    private var categoriesSection: some View {
        Section {
            if categories.isEmpty {
                Text("No hay carpetas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(categories) { category in
                    // 1. Fila de la Carpeta
                    CategoryHeaderRow(
                        category: category,
                        isSelected: selection == .category(category.id),
                        isCollapsed: collapsedCategories.contains(category.id),
                        onToggleCollapse: { toggleCollapse(category) },
                        onDropFeed: { feedUUID in moveFeed(withID: feedUUID, to: category) }
                    )
                    .tag(SidebarItem.category(category.id))
                    .contextMenu { categoryContextMenu(for: category) }

                    // 2. Feeds dentro de la carpeta (solo regulares de lectura)
                    if !collapsedCategories.contains(category.id) {
                        ForEach(category.feeds.filter { $0.isRegularArticleFeed }.sorted(by: { $0.addedDate < $1.addedDate })) { feed in
                            FeedRowView(feed: feed, isSelected: selection == .feed(feed.id), indented: true)
                                .tag(SidebarItem.feed(feed.id))
                                .contextMenu { feedContextMenu(for: feed) }
                        }
                    }
                }
            }
        } header: {
            categoriesSectionHeader
        }
    }

    @ViewBuilder
    private var categoriesSectionHeader: some View {
        HStack {
            Text("CARPETAS")
            Spacer()
            Button { showAddCategory = true } label: {
                Image(systemName: "plus").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
    }

    @ViewBuilder
    private var regularFeedsSection: some View {
        let label = categories.isEmpty ? "FEEDS DE NOTICIAS" : "SIN CARPETA"
        Section {
            ForEach(regularFeedsWithoutCategory) { feed in
                FeedRowView(feed: feed, isSelected: selection == .feed(feed.id))
                    .tag(SidebarItem.feed(feed.id))
                    .contextMenu { feedContextMenu(for: feed) }
            }
            .onDelete { offsets in deleteFeeds(from: regularFeedsWithoutCategory, at: offsets) }
        } header: {
            Text(label)
        }
        .onDrop(of: [UTType.text.identifier, UTType.plainText.identifier, "public.text"], isTargeted: $isUncategorizedTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                if let string = string as? String, let uuid = UUID(uuidString: string) {
                    DispatchQueue.main.async {
                        removeFeedFromCategory(uuid)
                    }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var youtubeSection: some View {
        Section {
            // Fila inteligente: Todos los videos
            SidebarSmartRow(
                icon: "play.rectangle.fill",
                iconColor: .red,
                label: "Todos los videos",
                count: totalYouTubeUnreadCount,
                isSelected: selection == .allVideos
            )
            .tag(SidebarItem.allVideos)

            // Canales de YouTube individuales
            ForEach(youtubeFeeds) { feed in
                FeedRowView(feed: feed, isSelected: selection == .feed(feed.id))
                    .tag(SidebarItem.feed(feed.id))
                    .contextMenu { feedContextMenu(for: feed) }
            }
            .onDelete { offsets in deleteFeeds(from: youtubeFeeds, at: offsets) }
        } header: {
            HStack {
                Text("YOUTUBE")
                Spacer()
                Button { showAddFeed = true } label: {
                    Image(systemName: "plus").font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var podcastsSection: some View {
        Section {
            // Fila inteligente: Todos los episodios
            SidebarSmartRow(
                icon: "waveform",
                iconColor: .purple,
                label: "Todos los episodios",
                count: totalPodcastsUnreadCount,
                isSelected: selection == .allPodcasts
            )
            .tag(SidebarItem.allPodcasts)

            // Podcasts seguidos individuales
            ForEach(podcastFeeds) { feed in
                FeedRowView(feed: feed, isSelected: selection == .feed(feed.id))
                    .tag(SidebarItem.feed(feed.id))
                    .contextMenu { feedContextMenu(for: feed) }
            }
            .onDelete { offsets in deleteFeeds(from: podcastFeeds, at: offsets) }
        } header: {
            HStack {
                Text("PODCASTS")
                Spacer()
                Button { showAddFeed = true } label: {
                    Image(systemName: "plus").font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.purple)
            }
        }
    }

    var body: some View {
        List(selection: $selection) {

            // ── 1. Vistas Inteligentes de Artículos ───────────────────────────
            Section("NOTICIAS & ARTÍCULOS") {
                SidebarSmartRow(
                    icon: "tray.2.fill",
                    iconColor: .accentColor,
                    label: "Todos los artículos",
                    count: totalArticlesUnreadCount,
                    isSelected: selection == .all
                )
                .tag(SidebarItem.all)

                SidebarSmartRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    label: "Favoritos",
                    count: 0,
                    isSelected: selection == .favorites
                )
                .tag(SidebarItem.favorites)
            }

            // ── 2. Carpetas de Artículos ─────────────────────────────────────
            categoriesSection

            // ── 3. Feeds de Noticias sin Carpeta ─────────────────────────────
            regularFeedsSection

            // ── 4. Sección Exclusiva: YOUTUBE ────────────────────────────────
            youtubeSection

            // ── 5. Sección Exclusiva: PODCASTS ───────────────────────────────
            podcastsSection
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if refreshService.isRefreshing {
                    ProgressView().scaleEffect(0.6).help("Actualizando feeds…")
                }

                Menu {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Nueva carpeta", systemImage: "folder.badge.plus")
                    }

                    Divider()

                    Button { showImportOPML = true } label: {
                        Label("Importar OPML…", systemImage: "square.and.arrow.down")
                    }
                    Button { exportOPML() } label: {
                        Label("Exportar OPML…", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("Opciones")

                Button { showAddFeed = true } label: {
                    Image(systemName: "plus")
                }
                .help("Añadir feed, canal o podcast (⌘N)")
            }
        }
        .navigationTitle("Feed Catcher")
        .safeAreaInset(edge: .bottom) {
            if let date = refreshService.lastRefreshDate {
                HStack {
                    Image(systemName: "arrow.clockwise").font(.caption2)
                    Text(date.reederTimeFormatted).font(.caption2)
                }
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(8)
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView()
        }
        .sheet(item: $editingCategory) { cat in
            AddCategoryView(editingCategory: cat)
        }
        .sheet(item: $movingFeed) { feed in
            MoveToCategoryView(feed: feed)
        }
        .fileImporter(
            isPresented: $showImportOPML,
            allowedContentTypes: [.init(filenameExtension: "opml") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleOPMLImport(result: result) }
        }
        .overlay(alignment: .bottom) { statusOverlayView }
        .animation(.easeInOut, value: isImporting)
        .animation(.easeInOut, value: importSuccess)
        .animation(.easeInOut, value: importError)
    }

    // MARK: - Drag and Drop Helpers

    private func moveFeed(withID id: UUID, to category: FeedCategory) {
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.id == id })
        if let feeds = try? modelContext.fetch(descriptor), let feed = feeds.first {
            feed.category = category
            try? modelContext.save()
            collapsedCategories.remove(category.id)
        }
    }

    private func removeFeedFromCategory(_ id: UUID) {
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.id == id })
        if let feeds = try? modelContext.fetch(descriptor), let feed = feeds.first {
            feed.category = nil
            try? modelContext.save()
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func categoryContextMenu(for category: FeedCategory) -> some View {
        Button {
            editingCategory = category
        } label: {
            Label("Editar carpeta", systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            deleteCategory(category)
        } label: {
            Label("Eliminar carpeta", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func feedContextMenu(for feed: Feed) -> some View {
        if feed.isRegularArticleFeed {
            Button {
                movingFeed = feed
            } label: {
                Label("Mover a carpeta…", systemImage: "folder")
            }
            Divider()
        }

        Button(role: .destructive) {
            deleteFeed(feed)
        } label: {
            Label(feed.isYouTubeFeed ? "Eliminar canal" : (feed.isPodcastFeed ? "Eliminar podcast" : "Eliminar feed"), systemImage: "trash")
        }
    }

    // MARK: - Status overlay

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
                    .font(.caption).foregroundStyle(.green)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importSuccess = nil }
                    }
            }
            if let error = importError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.yellow)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { importError = nil }
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Acciones

    private func toggleCollapse(_ category: FeedCategory) {
        if collapsedCategories.contains(category.id) {
            collapsedCategories.remove(category.id)
        } else {
            collapsedCategories.insert(category.id)
        }
    }

    private func deleteCategory(_ category: FeedCategory) {
        if case .category(let id) = selection, id == category.id {
            selection = .all
        }
        modelContext.delete(category)
        try? modelContext.save()
    }

    private func deleteFeed(_ feed: Feed) {
        if selection == .feed(feed.id) { selection = .all }
        modelContext.delete(feed)
        try? modelContext.save()
    }

    private func deleteFeeds(from list: [Feed], at offsets: IndexSet) {
        for index in offsets {
            let feed = list[index]
            if selection == .feed(feed.id) { selection = .all }
            modelContext.delete(feed)
        }
        try? modelContext.save()
    }

    // MARK: - OPML

    @MainActor
    private func handleOPMLImport(result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            isImporting = true; importError = nil; importSuccess = nil
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
                importSuccess = "\(newCount) feeds importados"
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func exportOPML() {
        let opml = OPMLService.shared.generateOPML(from: Array(feeds))
        guard let data = opml.data(using: .utf8) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "suscripciones-feedcatcher.opml"
        panel.allowedContentTypes = [.xml]
        if panel.runModal() == .OK, let url = panel.url { try? data.write(to: url) }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// CategoryHeaderRow — Fila de cabecera de carpeta
// ──────────────────────────────────────────────────────────────────────────────
struct CategoryHeaderRow: View {
    let category: FeedCategory
    let isSelected: Bool
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onDropFeed: (UUID) -> Void

    @State private var isDropTarget: Bool = false

    private var unreadCount: Int {
        category.feeds.filter { $0.isRegularArticleFeed }.reduce(0) { sum, feed in
            sum + feed.articles.filter { !$0.isRead }.count
        }
    }

    private var categoryColor: Color {
        Color(hex: category.colorHex) ?? Color.gray
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 22, height: 22)
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            Text(category.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                .lineLimit(1)

            Spacer()

            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor, in: Capsule())
            }

            Button(action: onToggleCollapse) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expandir carpeta" : "Colapsar carpeta")
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isDropTarget ? categoryColor.opacity(0.28) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isDropTarget ? categoryColor : Color.clear, lineWidth: 1.5)
        )
        .onDrop(of: [UTType.text.identifier, UTType.plainText.identifier, "public.text"], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                if let string = string as? String, let uuid = UUID(uuidString: string) {
                    DispatchQueue.main.async {
                        onDropFeed(uuid)
                    }
                }
            }
            return true
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SidebarSmartRow — Fila de vista inteligente
// ──────────────────────────────────────────────────────────────────────────────
private struct SidebarSmartRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(isSelected ? iconColor : iconColor.opacity(0.7))
                .frame(width: 18)
            Text(label)
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(iconColor, in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FeedRowView — Fila de feed arrastrable con favicon y contador
// ──────────────────────────────────────────────────────────────────────────────
struct FeedRowView: View {
    let feed: Feed
    var isSelected: Bool = false
    var indented: Bool = false

    var unreadCount: Int {
        feed.articles.filter { !$0.isRead }.count
    }

    var body: some View {
        HStack(spacing: 8) {
            if indented {
                Spacer().frame(width: 14)
            }

            if feed.isYouTubeFeed {
                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
                    .frame(width: 16)
            } else if feed.isPodcastFeed {
                Image(systemName: "waveform")
                    .foregroundStyle(.purple)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 16)
            } else {
                FaviconView(url: feed.resolvedFaviconURL, size: 16)
            }

            Text(feed.title)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(unreadCount > 0 ? 0.9 : 0.65))
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))

            Spacer()

            if unreadCount > 0 {
                let badgeColor: Color = feed.isYouTubeFeed ? .red : (feed.isPodcastFeed ? .purple : .accentColor)
                Text("\(unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor, in: Capsule())
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: feed.id.uuidString as NSString)
        }
    }
}
