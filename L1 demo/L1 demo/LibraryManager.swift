//LibraryManager.swift
import Foundation
import Combine

struct Playlist : Codable{
	var name : String = Constants.NewPlaylistName
	var songs : [String] = []
}

final class LibraryManager: ObservableObject {
	static let shared = LibraryManager()

	@Published var serverBaseURL: String = UserDefaults.standard.string(forKey: Constants.ServerURL) ?? ""

	//@Published var songs: [String] = []      // filenames already downloaded on-device
	@Published var library: [Playlist] = []
	@Published var queue: [String] = []
	@Published var isSyncing = false
	@Published var syncError: String?

	private let documentsDirectory: URL = {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}()

	private init() {
		library.append(Playlist(name: Constants.ConstantSongListName["AllSongsList"] ?? Constants.NameNotFound,songs: []))
		library.append(Playlist(name: Constants.ConstantSongListName["UnSortedList"] ?? Constants.NameNotFound,songs: []))
		refreshLocalSongs()
	}

	func setServerURL(_ url: String) {
		serverBaseURL = url
		UserDefaults.standard.set(url, forKey: Constants.ServerURL)
	}

	func localFileURL(for filename: String) -> URL {
		documentsDirectory.appendingPathComponent(filename)
	}

	func refreshLocalSongs() {
		let files = (try? FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path)) ?? []
		library[0].songs=files.filter { $0.hasSuffix(".mp3") }.sorted()
		loadlibrary()
		UpdateUnassignedSongList()
	}
	func UpdateUnassignedSongList(){
		library[1].songs=library[0].songs
		library.dropFirst(Constants.PreSetPlaylistCount).forEach{
			for song in $0.songs{
				if let index = library[1].songs.firstIndex(of: song){
					library[1].songs.remove(at: index)
					print(index, song, separator: ", ")
				}
			}
		}
	}

	/// Fetches the list of mp3s available on the Mac, downloads anything
	/// we don't already have locally.
	@MainActor
	func sync() async {
		guard !serverBaseURL.isEmpty, let base = URL(string: serverBaseURL) else {
			syncError = Constants.NoServerAddress
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
	public func movelibrary(songname song: String, from oldlis: String,to newlis: String){
		if let index=library.firstIndex(where: {$0.name==newlis}), Constants.ConstantSongListName.values.contains(library[index].name){
			library[index].songs.append(song)
			library[index].songs = Array(Set(library[index].songs)).sorted()
		}
		if let index=library.firstIndex(where: {$0.name==oldlis}), Constants.ConstantSongListName.values.contains(library[index].name){
			library[index].songs.removeAll { $0 == song}
			library[index].songs = Array(Set(library[index].songs)).sorted()
		}
		savelibrary()
		UpdateUnassignedSongList()
	}
	public func savelibrary(){
		let tosave = Array(library.dropFirst(Constants.PreSetPlaylistCount))
		if let data = try? JSONEncoder().encode(tosave){
			try? data.write(to: localFileURL(for: Constants.PlaylistFilename))
		}
	}
	public func loadlibrary(){
		guard let data = try? Data(contentsOf: localFileURL(for: Constants.PlaylistFilename)),
			let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else {return}
		library=Array(library.prefix(Constants.PreSetPlaylistCount))+decoded
	}
	public func removesong(songname song: String, from oldlis: String){
		if let index=library.firstIndex(where: {$0.name==oldlis}), Constants.ConstantSongListName.values.contains(library[index].name){
			library[index].songs.removeAll { $0 == song}
			library[index].songs = Array(Set(library[index].songs)).sorted()
		}
		savelibrary()
		UpdateUnassignedSongList()
	}
	public func addplaylist(name playlistname: String){
		library.append(Playlist(name: playlistname,songs: []))
	}
//	public func clearemptylist(){
//		for playlist in library.filter{$0.songs.isEmpty && !Constants.ConstantSongListName.values.contains($0.name)}{
//			//do sth
//		}
//	}
}
