import SwiftUI

struct ContentView: View {
	@StateObject private var audio = AudioManager.shared
	@StateObject private var library = LibraryManager.shared
	
	@State private var serverURLInput: String = LibraryManager.shared.serverBaseURL
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				//top bar to enter url gui thing
				VStack(alignment: .leading, spacing: 6) {
					//text thing
					Text("totally legit mp3 player")
						.font(.title.bold())
					Text("Server address")
						.font(.caption)
						.foregroundStyle(.secondary)
					//enter url field
					TextField("enter server url", text: $serverURLInput)
						.textFieldStyle(.roundedBorder)
						.autocorrectionDisabled()
						.textInputAutocapitalization(.never)
						.keyboardType(.URL)
					//syc lib button
					HStack{
						Spacer()
						Button {
							if !serverURLInput.isEmpty{
								library.setServerURL(serverURLInput)
								Task { await library.sync() }
							}
						} label: {
							if library.isSyncing {
								ProgressView()
							} else if serverURLInput.isEmpty{
								Label("Input server first", systemImage: "exclamationmark.triangle")
									.foregroundStyle(.red)
							}else {
								Label("Sync library", systemImage: "arrow.triangle.2.circlepath")
							}
						}
						.disabled(library.isSyncing)
						
						if let error = library.syncError {
							Text(error)
								.font(.caption)
								.foregroundStyle(.red)
						}
					}
				}
				.padding()
				Divider()
				//song list
				List(library.library, id: \.name) { list in
					NavigationLink(list.name){
						showsonglist(list: list)
					}
				}

				Divider()
				
				//song currently played controls
				playerControls
					.padding()
			}
			.onAppear { library.refreshLocalSongs() }
		}
	}
	@ViewBuilder
	private func showsonglist(list : Playlist) -> some View{
		VStack{
			Text(list.name)
				.font(.title.bold())
				.padding(.top,65)
				.padding(.leading,75)
				.ignoresSafeArea()
				.frame(maxWidth: .infinity, alignment: .leading)
			if list.songs.isEmpty{
				Text("no media imported")
			}else{
				List(list.songs, id: \.self) { filename in
					Button {
						let url = library.localFileURL(for: filename)
						audio.loadTrack(url: url, title: filename)
					} label: {
						HStack {
							Text(filename)
								.lineLimit(1)
							Spacer()
							if audio.currentTitle == filename {
								Image(systemName: "speaker.wave.2.fill")
									.foregroundStyle(.blue)
							}
						}
					}
				}
				.listStyle(.plain)
				.padding(.top,-65)
			}
			Spacer()
			playerControls
				.padding()
		}
	}
	private var playerControls: some View {
		VStack() {
			Text(audio.currentTitle)
				.font(.headline)
				.lineLimit(1)
			
			VStack(spacing: 4) {
				Slider(
					value: Binding(
						get: { audio.currentTime },
						set: { audio.seek(to: $0) }
					),
					in: 0...(max(audio.duration, 1))
				)
				HStack {
					Text(formatTime(audio.currentTime))
					Spacer()
					Text(formatTime(audio.duration))
				}
				.font(.caption2)
				.foregroundStyle(.secondary)
			}
			
			Button {
				audio.togglePlayPause()
			} label: {
				Image(systemName: audio.isPlaying ? "pause.circle" : "play.circle.fill")
					.font(.system(size: 45))
			}
			.buttonStyle(.plain)
		}
	}
	private func formatTime(_ seconds: Double) -> String {
		guard seconds.isFinite, seconds >= 0 else { return "0:00" }
		let m = Int(seconds) / 60
		let s = Int(seconds) % 60
		return String(format: "%d:%02d", m, s)
	}
}
#Preview {
	ContentView()
}
