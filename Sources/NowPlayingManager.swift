import AppKit
import Combine
import Foundation

struct Track: Equatable {
    let title: String
    let artist: String
    let album: String?
    let artwork: NSImage?
    let duration: Double

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
    }
}

@MainActor
class NowPlayingManager: ObservableObject {
    @Published var track: Track?
    @Published var isPlaying: Bool = false
    @Published var elapsed: Double = 0
    @Published var duration: Double = 0

    private var progressTimer: Timer?
    private var lastFetchedPosition: Double = 0
    private var lastFetchTime: Date = .now

    init() {
        setupNotifications()
        fetchViaAppleScript()
        startProgressTimer()
    }

    private func setupNotifications() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleMusicNotification(notification) }
        }
    }

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying, self.duration > 0 else { return }
                let delta = Date.now.timeIntervalSince(self.lastFetchTime)
                self.elapsed = min(self.lastFetchedPosition + delta, self.duration)
            }
        }
    }

    // MARK: - AppleScript

    func fetchViaAppleScript() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            tell application "System Events"
                if not (exists process "Music") then return "NOT_RUNNING"
            end tell
            tell application "Music"
                if player state is stopped then return "STOPPED"
                set pState to "Playing"
                if player state is paused then set pState to "Paused"
                set t to current track
                set info to name of t & "||" & artist of t & "||" & album of t & "||" & (duration of t as string) & "||" & (player position as string) & "||" & pState
                return info
            end tell
            """

            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let result = appleScript?.executeAndReturnError(&error)

            // Fetch artwork separately
            var artworkImage: NSImage?
            let artworkScript = """
            tell application "Music"
                if player state is not stopped then
                    try
                        set artData to raw data of artwork 1 of current track
                        return artData
                    end try
                end if
            end tell
            """
            let artAS = NSAppleScript(source: artworkScript)
            var artErr: NSDictionary?
            if let artResult = artAS?.executeAndReturnError(&artErr) {
                let artData = artResult.data
                artworkImage = NSImage(data: artData)
            }

            Task { @MainActor in
                guard let self else { return }
                guard let output = result?.stringValue else {
                    self.clearTrack()
                    return
                }

                if output == "NOT_RUNNING" || output == "STOPPED" {
                    self.clearTrack()
                    return
                }

                let parts = output.components(separatedBy: "||")
                guard parts.count >= 6 else {
                    self.clearTrack()
                    return
                }

                let title = parts[0]
                let artist = parts[1]
                let album = parts[2].isEmpty ? nil : parts[2]
                let dur = Double(parts[3]) ?? 0
                let pos = Double(parts[4]) ?? 0
                let state = parts[5]

                self.track = Track(title: title, artist: artist, album: album, artwork: artworkImage, duration: dur)
                self.isPlaying = state == "Playing"
                self.duration = dur
                self.lastFetchedPosition = pos
                self.lastFetchTime = .now
                self.elapsed = pos
            }
        }
    }

    // MARK: - Distributed Notification

    private func handleMusicNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }

        let name = info["Name"] as? String
        let artist = info["Artist"] as? String
        let album = info["Album"] as? String
        let state = info["Player State"] as? String
        let dur = info["Total Time"] as? Double

        if let name, let artist, state != "Stopped" {
            let trackChanged = track?.title != name || track?.artist != artist

            isPlaying = state == "Playing"
            duration = (dur ?? 0) / 1000 // Total Time is in ms
            lastFetchedPosition = 0
            lastFetchTime = .now
            elapsed = 0

            if trackChanged {
                // Fetch full info including artwork for new tracks
                fetchViaAppleScript()
            } else {
                track = Track(title: name, artist: artist, album: album, artwork: track?.artwork, duration: duration)
            }
        } else if state == "Stopped" {
            clearTrack()
        }
    }

    private func clearTrack() {
        track = nil
        isPlaying = false
        elapsed = 0
        duration = 0
    }

    // MARK: - Playback Controls

    private func runMusicCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = "tell application \"Music\" to \(command)"
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            Task { @MainActor in
                self?.fetchViaAppleScript()
            }
        }
    }

    func togglePlayPause() {
        runMusicCommand("playpause")
    }

    func nextTrack() {
        runMusicCommand("next track")
    }

    func previousTrack() {
        runMusicCommand("previous track")
    }

    func seek(to position: Double) {
        elapsed = position
        lastFetchedPosition = position
        lastFetchTime = .now
        runMusicCommand("set player position to \(position)")
    }
}
