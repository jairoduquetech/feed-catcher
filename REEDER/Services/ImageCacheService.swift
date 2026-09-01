import SwiftUI
import AppKit

// ──────────────────────────────────────────────────────────────────────────────
// ImageCacheService — Caché de imágenes de alto rendimiento en memoria y disco
// Evita descargas repetidas y decodificación en el hilo principal durante el scroll.
// ──────────────────────────────────────────────────────────────────────────────

final class ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL

    private init() {
        memoryCache.countLimit = 500              // Hasta 500 imágenes en RAM
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB de RAM máx

        // Directorio de caché en disco
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = caches.appendingPathComponent("FeedCatcherImages", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Configurar URLCache global para peticiones de red
        URLCache.shared.memoryCapacity = 50 * 1024 * 1024  // 50 MB
        URLCache.shared.diskCapacity = 200 * 1024 * 1024   // 200 MB
    }

    func image(for urlString: String) -> NSImage? {
        let key = NSString(string: urlString)
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // Buscar en disco si no está en RAM
        let fileURL = diskCacheURL.appendingPathComponent(cacheKey(for: urlString))
        if let data = try? Data(contentsOf: fileURL), let diskImage = NSImage(data: data) {
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        return nil
    }

    func insertImage(_ image: NSImage, for urlString: String, data: Data? = nil) {
        let key = NSString(string: urlString)
        memoryCache.setObject(image, forKey: key)

        // Guardar en disco en segundo plano
        Task.detached(priority: .background) { [diskCacheURL, fileManager] in
            let fileURL = diskCacheURL.appendingPathComponent(Self.cacheKeyStatic(for: urlString))
            if let d = data {
                try? d.write(to: fileURL)
            } else if let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: fileURL)
            }
        }
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        URLCache.shared.removeAllCachedResponses()
    }

    var cacheSizeInMB: String {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }
        var totalBytes: Int64 = 0
        for file in files {
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                totalBytes += Int64(size)
            }
        }
        let mb = Double(totalBytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    private func cacheKey(for urlString: String) -> String {
        Self.cacheKeyStatic(for: urlString)
    }

    private static func cacheKeyStatic(for urlString: String) -> String {
        let safe = urlString.data(using: .utf8)?.base64EncodedString() ?? "\(urlString.hashValue)"
        return safe.replacingOccurrences(of: "/", with: "_").prefix(120) + ".img"
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// CachedAsyncImageView — Vista de imagen con caché instantáneo y 0 tirones
// ──────────────────────────────────────────────────────────────────────────────
struct CachedAsyncImageView<Content: View, Placeholder: View>: View {
    let urlString: String?
    let targetSize: CGSize?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: NSImage? = nil

    init(
        urlString: String?,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.targetSize = targetSize
        self.content = content
        self.placeholder = placeholder

        // Comprobación síncrona inmediata en inicialización (0ms de lag si está en RAM)
        if let str = urlString, let cached = ImageCacheService.shared.image(for: str) {
            _loadedImage = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let nsImage = loadedImage {
                content(Image(nsImage: nsImage))
            } else {
                placeholder()
                    .task(id: urlString) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }

        // Si ya está en caché, no hacer petición de red
        if let cached = ImageCacheService.shared.image(for: urlString) {
            await MainActor.run { self.loadedImage = cached }
            return
        }

        // Descargar en segundo plano
        do {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)

            if let img = NSImage(data: data) {
                // Downsample si se especificó tamaño para ahorrar memoria en scroll
                let finalImage: NSImage
                if let target = targetSize, target.width > 0, target.height > 0 {
                    finalImage = downsample(image: img, to: target) ?? img
                } else {
                    finalImage = img
                }

                ImageCacheService.shared.insertImage(finalImage, for: urlString, data: data)
                await MainActor.run {
                    self.loadedImage = finalImage
                }
            }
        } catch {
            // Falla silenciosa con fallback
        }
    }

    private func downsample(image: NSImage, to size: CGSize) -> NSImage? {
        guard let tiff = image.tiffRepresentation,
              let source = CGImageSourceCreateWithData(tiff as CFData, nil) else { return nil }

        let maxDimension = max(size.width, size.height) * 2 // 2x para retina displays
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let downsampled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: downsampled, size: size)
    }
}
