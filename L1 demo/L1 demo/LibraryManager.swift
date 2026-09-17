import Foundation
import Combine

struct Playlist{
	var name : String = "new playlist"
	var songs : [String] = []
}

final class LibraryManager: ObservableObject {
	static let shared = LibraryManager()

	@Published var serverBaseURL: String = UserDefaults.standard.string(forKey: "serverBaseURL") ?? ""

	//@Published var songs: [String] = []      // filenames already downloaded on-device
	@Published var library: [Playlist] = [Playlist()]
	@Published var isSyncing = false
	@Published var syncError: String?

	private let documentsDirectory: URL = {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}()

	private init() {
		refreshLocalSongs()
	}

	func setServerURL(_ url: String) {
		serverBaseURL = url
		UserDefaults.standard.set(url, forKey: "serverBaseURL")
	}

	func localFileURL(for filename: String) -> URL {
		documentsDirectory.appendingPathComponent(filename)
	}

	func refreshLocalSongs() {
		let files = (try? FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path)) ?? []
		//songs = files.filter { $0.hasSuffix(".mp3") }.sorted()
		library[0].songs=files.filter { $0.hasSuffix(".mp3") }.sorted()
		library[0].name="testing playlist"
	}

	/// Fetches the list of mp3s available on the Mac, downloads anything
	/// we don't already have locally.
	@MainActor
	func sync() async {
		guard !serverBaseURL.isEmpty, let base = URL(string: serverBaseURL) else {
			syncError = "No server address set."
			return
		}

		isSyncing = true
		syncError = nil

		do {
			let libraryURL = base.appendingPathComponent("library")
			let (data, _) = try await URLSession.shared.data(from: libraryURL)
			let remoteFilenames = try JSONDecoder().decode([String].self, from: data)

			refreshLocalSongs()
			let alreadyHave = Set(library[0].songs)
			let missing = remoteFilenames.filter { !alreadyHave.contains($0) }

			for filename in missing {
				try await downloadFile(named: filename, from: base)
			}

			refreshLocalSongs()
		} catch {
			syncError = error.localizedDescription
		}

		isSyncing = false
	}

	private func downloadFile(named filename: String, from base: URL) async throws {
		guard let url = downloadURL(for: filename, base: base) else {
			throw URLError(.badURL)
		}
		let (tempURL, _) = try await URLSession.shared.download(from: url)
		let destination = localFileURL(for: filename)
		if FileManager.default.fileExists(atPath: destination.path) {
			try FileManager.default.removeItem(at: destination)
		}
		try FileManager.default.moveItem(at: tempURL, to: destination)
	}

	private func downloadURL(for filename: String, base: URL) -> URL? {
		// Percent-encode the filename (handles spaces, Japanese, etc.)
		// before appending it manually — appendingPathComponent alone
		// can mishandle characters like '#' or '%' in titles.
		guard let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
			return nil
		}
		let trimmedBase = base.absoluteString.hasSuffix("/")
			? String(base.absoluteString.dropLast())
			: base.absoluteString
		return URL(string: "\(trimmedBase)/files/\(encoded)")
	}
}
