import Foundation
import AVFoundation
import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// AudioPlayerService — Reproductor de audio nativo para podcasts
// ──────────────────────────────────────────────────────────────────────────────

@Observable
final class AudioPlayerService {

    static let shared = AudioPlayerService()
    private init() {
        setupTimeObserver()
    }

    private var player: AVPlayer?
    private var timeObserverToken: Any?

    var currentArticleID: UUID? = nil
    var currentTitle: String = ""
    var currentPodcastName: String = ""
    var currentArtworkURL: String? = nil
    var currentAudioURLString: String? = nil

    var isPlaying: Bool = false
    var isLoading: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Float = 1.0

    var isMiniPlayerVisible: Bool {
        currentAudioURLString != nil
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    var durationFormatted: String {
        formatTime(duration)
    }

    var remainingTimeFormatted: String {
        let remaining = max(duration - currentTime, 0)
        return "-" + formatTime(remaining)
    }

    // MARK: - Controles de reproducción

    func play(urlString: String, title: String, podcast: String, artworkURL: String?, articleID: UUID? = nil) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }

        // Si es el mismo archivo, solo alternar play/pause
        if currentAudioURLString == urlString {
            togglePlayPause()
            return
        }

        cleanup()

        currentAudioURLString = urlString
        currentTitle = title
        currentPodcastName = podcast
        currentArtworkURL = artworkURL
        currentArticleID = articleID
        isLoading = true
        isPlaying = true
        currentTime = 0
        duration = 0

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.rate = playbackRate

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        setupTimeObserver()

        // Observar estado del item
        Task { [weak self] in
            guard let self else { return }
            for await status in item.publisher(for: \.status).values {
                if status == .readyToPlay {
                    await MainActor.run {
                        self.isLoading = false
                        let dur = item.duration.seconds
                        if !dur.isNaN && dur > 0 {
                            self.duration = dur
                        }
                        if self.isPlaying {
                            self.player?.play()
                            self.player?.rate = self.playbackRate
                        }
                    }
                    break
                } else if status == .failed {
                    await MainActor.run {
                        self.isLoading = false
                        self.isPlaying = false
                    }
                    break
                }
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            player.rate = playbackRate
            isPlaying = true
        }
    }

    func seek(to percentage: Double) {
        guard let player, duration > 0 else { return }
        let targetSeconds = percentage * duration
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = targetSeconds
    }

    func skipForward(seconds: Double = 15) {
        guard let player else { return }
        let newTime = min(currentTime + seconds, duration > 0 ? duration : currentTime + seconds)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: targetTime)
        currentTime = newTime
    }

    func skipBackward(seconds: Double = 15) {
        guard let player else { return }
        let newTime = max(currentTime - seconds, 0)
        let targetTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: targetTime)
        currentTime = newTime
    }

    func cyclePlaybackRate() {
        let rates: [Float] = [1.0, 1.25, 1.5, 2.0]
        if let idx = rates.firstIndex(of: playbackRate) {
            playbackRate = rates[(idx + 1) % rates.count]
        } else {
            playbackRate = 1.0
        }
        if isPlaying {
            player?.rate = playbackRate
        }
    }

    func close() {
        cleanup()
        currentAudioURLString = nil
        currentTitle = ""
        currentPodcastName = ""
        currentArtworkURL = nil
        currentArticleID = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
    }

    private func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func playerItemDidReachEnd() {
        isPlaying = false
        currentTime = duration
    }

    private func setupTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let secs = time.seconds
            if !secs.isNaN {
                self.currentTime = secs
            }
            if let item = player.currentItem {
                let dur = item.duration.seconds
                if !dur.isNaN && dur > 0 && self.duration != dur {
                    self.duration = dur
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
