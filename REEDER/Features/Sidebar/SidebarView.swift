import SwiftUI
import SwiftData

// ──────────────────────────────────────────────────────────────────────────────
// SidebarItem — Enum para la selección de la barra lateral
// ──────────────────────────────────────────────────────────────────────────────
enum SidebarItem: Hashable, Identifiable {
    case all
    case favorites
    case category(UUID)
    case feed(UUID)

    var id: String {
        switch self {
        case .all:              return "all"
        case .favorites:        return "favorites"
        case .category(let id): return "cat-\(id.uuidString)"
        case .feed(let id):     return id.uuidString
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SidebarView v7 — Vistas inteligentes + Carpetas colapsables + Feeds sin categoría
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

    private var feedsWithoutCategory: [Feed] {
        feeds.filter { $0.category == nil }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        Section {
            ForEach(categories) { cat in
                SidebarCategoryRow(
                    category: cat,
                    selection: $selection,
                    collapsedCategories: $collapsedCategories,
                    movingFeed: $movingFeed,
                    editingCategory: $editingCategory
                )
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
    private var feedsSection: some View {
        if !feedsWithoutCategory.isEmpty {
            let label = categories.isEmpty ? "FEEDS" : "SIN CARPETA"
            Section(label) {
                ForEach(feedsWithoutCategory) { feed in
                    FeedRowView(feed: feed, isSelected: selection == .feed(feed.id))
                        .contentShape(Rectangle())
                        .onTapGesture { selection = .feed(feed.id) }
                        .tag(SidebarItem.feed(feed.id))
                        .contextMenu { feedContextMenu(for: feed) }
                }
                .onDelete { offsets in deleteFeeds(from: feedsWithoutCategory, at: offsets) }
            }
        }
    }

    var body: some View {
        List(selection: $selection) {

            // ── Vistas Inteligentes ───────────────────────────────────────────
            Section("VISTAS INTELIGENTES") {
                SidebarSmartRow(
                    icon: "tray.2.fill",
                    iconColor: .accentColor,
                    label: "Todos los artículos",
                    count: totalUnreadCount,
                    isSelected: selection == .all
                )
                .contentShape(Rectangle())
                .onTapGesture { selection = .all }
                .tag(SidebarItem.all)

                SidebarSmartRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    label: "Favoritos",
                    count: 0,
                    isSelected: selection == .favorites
                )
                .contentShape(Rectangle())
                .onTapGesture { selection = .favorites }
                .tag(SidebarItem.favorites)
            }

            // ── Categorías ───────────────────────────────────────────────────
            categoriesSection

            // ── Feeds sin categoría ──────────────────────────────────────────
            feedsSection
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
                .help("Añadir feed (⌘N)")
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

    // MARK: - Category Context Menu

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

    // MARK: - Feed Context Menu

    @ViewBuilder
    private func feedContextMenu(for feed: Feed) -> some View {
        Button {
            movingFeed = feed
        } label: {
            Label("Mover a carpeta…", systemImage: "folder")
        }

        Divider()

        Button(role: .destructive) {
            deleteFeed(feed)
        } label: {
            Label("Eliminar feed", systemImage: "trash")
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
        // Los feeds pasan a "Sin categoría" gracias a deleteRule: .nullify
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
// ──────────────────────────────────────────────────────────────────────────────
// SidebarCategoryRow — Wrapper self-contained para evitar problemas de type-checking
// ──────────────────────────────────────────────────────────────────────────────
struct SidebarCategoryRow: View {
    let category: FeedCategory
    @Binding var selection: SidebarItem
    @Binding var collapsedCategories: Set<UUID>
    @Binding var movingFeed: Feed?
    @Binding var editingCategory: FeedCategory?

    @Environment(\.modelContext) private var modelContext

    private var collapsed: Bool { collapsedCategories.contains(category.id) }

    var body: some View {
        CategorySectionView(
            category: category,
            selection: $selection,
            collapsed: collapsed,
            movingFeed: $movingFeed
        )
        .contextMenu {
            Button {
                editingCategory = category
            } label: {
                Label("Editar carpeta", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                deleteCategory()
            } label: {
                Label("Eliminar carpeta", systemImage: "trash")
            }
        }
        .onTapGesture {
            if collapsedCategories.contains(category.id) {
                collapsedCategories.remove(category.id)
            } else {
                collapsedCategories.insert(category.id)
            }
        }
    }

    private func deleteCategory() {
        if case .category(let id) = selection, id == category.id {
            selection = .all
        }
        modelContext.delete(category)
        try? modelContext.save()
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// CategorySectionView — Fila de categoría colapsable con sus feeds adentro
// ──────────────────────────────────────────────────────────────────────────────
struct CategorySectionView: View {
    let category: FeedCategory
    @Binding var selection: SidebarItem
    let collapsed: Bool
    @Binding var movingFeed: Feed?

    @Environment(\.modelContext) private var modelContext

    private var unreadCount: Int { category.unreadCount }

    var body: some View {
        VStack(spacing: 0) {
            // Cabecera de la categoría (clicable para expandir/colapsar y seleccionar)
            HStack(spacing: 8) {
                // Ícono de la categoría con su color
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: category.colorHex)?.opacity(0.2) ?? Color.gray.opacity(0.2))
                        .frame(width: 22, height: 22)
                    Image(systemName: category.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: category.colorHex) ?? .gray)
                }

                Text(category.name)
                    .font(.system(size: 13, weight: selection == .category(category.id) ? .semibold : .regular))
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: category.colorHex) ?? .accentColor, in: Capsule())
                }

                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                selection == .category(category.id)
                    ? (Color(hex: category.colorHex) ?? .accentColor).opacity(0.1)
                    : Color.clear
            )
            .tag(SidebarItem.category(category.id))
            .simultaneousGesture(
                TapGesture().onEnded {
                    selection = .category(category.id)
                }
            )

            // Feeds de esta categoría (si no está colapsada)
            if !collapsed {
                ForEach(category.feeds.sorted(by: { $0.addedDate < $1.addedDate })) { feed in
                    FeedRowView(feed: feed, isSelected: selection == .feed(feed.id), indented: true)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = .feed(feed.id) }
                        .tag(SidebarItem.feed(feed.id))
                        .contextMenu {
                            Button {
                                movingFeed = feed
                            } label: {
                                Label("Mover a carpeta…", systemImage: "folder")
                            }
                            Divider()
                            Button(role: .destructive) {
                                if selection == .feed(feed.id) { selection = .all }
                                modelContext.delete(feed)
                                try? modelContext.save()
                            } label: {
                                Label("Eliminar feed", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// SidebarSmartRow — Fila de vista inteligente (Todos / Favoritos)
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
        .padding(.vertical, 2)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// FeedRowView — Fila de feed con favicon y contador
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
