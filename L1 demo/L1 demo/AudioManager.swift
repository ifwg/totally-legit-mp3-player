import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class AudioManager: ObservableObject {
	static let shared = AudioManager()
	@Published var isPlaying = false
	@Published var currentTime: Double = 0
	@Published var duration: Double = 0
	@Published var currentTitle: String = "No song selected"
	@Published var queue: [Int] = []

	private var player: AVPlayer?
	private var timeObserverToken: Any?
	private var statusCancellable: AnyCancellable?
	private var endObserver: NSObjectProtocol?

	private init() {
		DispatchQueue.main.async { [weak self] in
			self?.configureAudioSession()
			self?.setupRemoteCommandCenter()
		}
	}

	// MARK: - Setup

	private func configureAudioSession() {
		do {
			let session = AVAudioSession.sharedInstance()
			try session.setCategory(.playback, mode: .default, options: [])
			try session.setActive(true)
		} catch {
			print("Failed to configure audio session: \(error)")
		}
	}

	/// Loads and starts playing a track from any local file URL —
	/// either the bundled demo song or a synced-from-Mac song in
	/// the Documents directory.
	func loadTrack(url: URL, title: String) {
		// Tear down the previous item's observers before swapping.
		if let token = timeObserverToken {
			player?.removeTimeObserver(token)
			timeObserverToken = nil
		}
		if let endObserver {
			NotificationCenter.default.removeObserver(endObserver)
		}
		statusCancellable?.cancel()

		currentTitle = title
		currentTime = 0
		duration = 0

		let item = AVPlayerItem(url: url)
		if let player {
			player.replaceCurrentItem(with: item)
		} else {
			player = AVPlayer(playerItem: item)
		}

		statusCancellable = item.publisher(for: \.status)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] status in
				if status == .readyToPlay {
					self?.duration = item.duration.seconds
					self?.updateNowPlayingInfo()
				} else if status == .failed {
					print("Playback failed: \(item.error?.localizedDescription ?? "unknown error")")
				}
			}

		let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
		timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
			self?.currentTime = time.seconds
			self?.updateNowPlayingInfo()
		}

		endObserver = NotificationCenter.default.addObserver(
			forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
		) { [weak self] _ in
			self?.trackDidFinish()
		}

		play()
	}

	private func trackDidFinish() {
		player?.seek(to: .zero)
		player?.play()   // loop — remove this line if you'd rather it just stop
		isPlaying = true
		updateNowPlayingInfo()
	}

	// MARK: - Transport controls

	func togglePlayPause() {
		isPlaying ? pause() : play()
	}

	func play() {
		player?.play()
		isPlaying = true
		updateNowPlayingInfo()
	}

	func pause() {
		player?.pause()
		isPlaying = false
		updateNowPlayingInfo()
	}

	func seek(to seconds: Double) {
		let time = CMTime(seconds: seconds, preferredTimescale: 600)
		player?.seek(to: time)
		currentTime = seconds
		updateNowPlayingInfo()
	}

	// MARK: - AirPods / lock screen / Control Center integration

	private func setupRemoteCommandCenter() {
		let commandCenter = MPRemoteCommandCenter.shared()

		commandCenter.playCommand.addTarget { [weak self] _ in
			self?.play(); return .success
		}
		commandCenter.pauseCommand.addTarget { [weak self] _ in
			self?.pause(); return .success
		}
		commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
			self?.togglePlayPause(); return .success
		}

		// TODO: once the library has multiple songs, wire these to
		// advance through LibraryManager.songs instead of restarting.
		commandCenter.nextTrackCommand.addTarget { [weak self] _ in
			self?.seek(to: 0); self?.play(); return .success
		}
		commandCenter.previousTrackCommand.addTarget { [weak self] _ in
			self?.seek(to: 0); self?.play(); return .success
		}

		commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
			guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
			self?.seek(to: event.positionTime)
			return .success
		}
	}

	private func updateNowPlayingInfo() {
		let info: [String: Any] = [
			MPMediaItemPropertyTitle: currentTitle,
			MPMediaItemPropertyPlaybackDuration: duration,
			MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
			MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
		]
		MPNowPlayingInfoCenter.default().nowPlayingInfo = info
	}

	deinit {
		if let token = timeObserverToken {
			player?.removeTimeObserver(token)
		}
	}
}
