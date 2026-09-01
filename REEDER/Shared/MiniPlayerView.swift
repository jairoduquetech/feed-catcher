import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// MiniPlayerView — Barra de reproducción flotante persistente para Podcasts
// ──────────────────────────────────────────────────────────────────────────────

struct MiniPlayerView: View {
    @State private var player = AudioPlayerService.shared
    @State private var isHovered = false

    var body: some View {
        if player.isMiniPlayerVisible {
            VStack(spacing: 0) {
                // Barra de progreso superior interactiva (Scrubber)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 3)

                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geo.size.width * CGFloat(player.progress), height: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let pct = max(0, min(1, value.location.x / geo.size.width))
                                player.seek(to: Double(pct))
                            }
                    )
                }
                .frame(height: 3)

                // Controles principales del mini-player
                HStack(spacing: 12) {
                    // Carátula del podcast
                    ZStack {
                        if let art = player.currentArtworkURL, !art.isEmpty {
                            CachedAsyncImageView(urlString: art, targetSize: CGSize(width: 40, height: 40)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6).fill(Color.purple.opacity(0.2))
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.purple.opacity(0.2))
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    // Información del episodio
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(player.currentPodcastName)
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .lineLimit(1)

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.5))

                            Text("\(player.currentTimeFormatted) / \(player.durationFormatted)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 12)

                    // Botón -15s
                    Button {
                        player.skipBackward(seconds: 15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Retroceder 15 segundos")

                    // Botón Play / Pause
                    Button {
                        player.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 32, height: 32)

                            if player.isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .colorInvert()
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: player.isPlaying ? 0 : 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(player.isPlaying ? "Pausar" : "Reproducir")

                    // Botón +15s
                    Button {
                        player.skipForward(seconds: 15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Adelantar 15 segundos")

                    // Selector de velocidad (1x, 1.25x, 1.5x, 2x)
                    Button {
                        player.cyclePlaybackRate()
                    } label: {
                        Text(String(format: "%.2gx", player.playbackRate))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Cambiar velocidad de reproducción")

                    // Botón Cerrar
                    Button {
                        player.close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Detener y cerrar reproductor")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.regularMaterial)
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.2), value: player.isMiniPlayerVisible)
        }
    }
}
