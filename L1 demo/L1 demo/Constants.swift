//
//  Constants.swift
//  L1 demo
//
//  Created by Lido on 21/9/26.
//

import Foundation
struct Constants {
	//text output thing
	static let ConstantSongListName: [String: String]=[
		"AllSongsList": "All songs",
		"UnSortedList": "Unassigned songs"
//		"NewPlaylistName" : "New Playlist"
	]
	static let NewPlaylistName = "New Playlist"
//	static let AllSongsList = "All songs"
//	static let UnSortedList = "Unassigned songs"
	static let NameNotFound = "Name not found"
	static let NoSongSelected = "No song selected"
	static let NoPlaylistSelected = "No playlist selected"
	static let RemoveSongFromPlaylist = "Remove song from playlist"
	static let AddNewPlaylist = "Add Playlist"
	static let RemovePlaylist = "Delete playlist"
	// thing
	static let Shuffle = "Shuffle"
	static let Repeat = "Repeat"
	//test output error
	static let NoSongsError = "No songs imported"
	static let NoServerAddress = "No server address set"
	static let UnknownError = "Unknown error"
	//thingy key for storing data
	static let ServerURL = "serverBaseURL"
	static let PlaylistFilename = "playlists.json"
	//numbers
	static let PreSetPlaylistCount = 2
}
