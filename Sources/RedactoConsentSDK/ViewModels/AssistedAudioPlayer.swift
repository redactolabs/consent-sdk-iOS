import AVFoundation
import Foundation

/// Plays one narration clip at a time for the assisted notice.
@MainActor
protocol AssistedAudioPlaying: AnyObject {
    /// Starts `url`, replacing whatever was playing. Exactly one of the
    /// callbacks fires, once, unless `stop()` or another `play` comes first.
    func play(url: URL, onEnd: @escaping @MainActor () -> Void, onError: @escaping @MainActor () -> Void)
    func pause()
    func resume()
    func stop()
}

@MainActor
final class AssistedAVAudioPlayer: AssistedAudioPlaying {
    private var player: AVPlayer?
    private var observers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?
    private var generation = 0

    func play(url: URL, onEnd: @escaping @MainActor () -> Void, onError: @escaping @MainActor () -> Void) {
        stop()
        let current = generation
        let item = AVPlayerItem(url: url)
        let finish: (@escaping @MainActor () -> Void) -> Void = { [weak self] callback in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.generation += 1
                callback()
            }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in finish(onEnd) })
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { _ in finish(onError) })
        statusObservation = item.observe(\.status) { item, _ in
            if item.status == .failed {
                finish(onError)
            }
        }
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.play()
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        generation += 1
        player?.pause()
        player = nil
        statusObservation = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}
