import SwiftUI

@main
struct MuseBarApp: App {
    @StateObject private var nowPlaying = NowPlayingManager()

    var body: some Scene {
        MenuBarExtra {
            PlayerView(nowPlaying: nowPlaying)
        } label: {
            if let track = nowPlaying.track, nowPlaying.isPlaying {
                HStack(spacing: 6) {
                    if let artwork = track.artwork {
                        Image(nsImage: resizedMenuBarImage(artwork))
                            .renderingMode(.original)
                    } else {
                        Image(systemName: "music.note")
                    }
                    let display = "\(track.artist) — \(track.title)"
                    Text(display.count > 50 ? String(display.prefix(47)) + "..." : display)
                }
            } else {
                Image(systemName: "music.note")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private func resizedMenuBarImage(_ image: NSImage) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let resized = NSImage(size: size)
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: size))
    resized.unlockFocus()
    resized.isTemplate = false
    return resized
}

struct PlayerView: View {
    @ObservedObject var nowPlaying: NowPlayingManager

    var body: some View {
        VStack(spacing: 0) {
            if let track = nowPlaying.track {
                // Artwork + track info
                HStack(spacing: 12) {
                    if let artwork = track.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let album = track.album {
                            Text(album)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .contentShape(Rectangle())
                .onTapGesture { nowPlaying.revealInMusic() }
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                // Seekable progress bar
                if nowPlaying.duration > 0 {
                    VStack(spacing: 4) {
                        SeekBar(value: nowPlaying.elapsed, total: nowPlaying.duration) { position in
                            nowPlaying.seek(to: position)
                        }

                        HStack {
                            Text(formatTime(nowPlaying.elapsed))
                            Spacer()
                            Text("-" + formatTime(nowPlaying.duration - nowPlaying.elapsed))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Playback controls
                HStack(spacing: 20) {
                    ControlButton(systemName: "backward.fill", size: .title3) {
                        nowPlaying.previousTrack()
                    }
                    ControlButton(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: .title2) {
                        nowPlaying.togglePlayPause()
                    }
                    ControlButton(systemName: "forward.fill", size: .title3) {
                        nowPlaying.nextTrack()
                    }
                }
                .padding(.bottom, 10)

                Divider()
            } else {
                Text("Nothing playing")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
                Divider()
            }

            Button("Quit MuseBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct SeekBar: View {
    let value: Double
    let total: Double
    let onSeek: (Double) -> Void

    @State private var isHovering = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)

                Capsule()
                    .fill(.primary)
                    .frame(width: max(0, geo.size.width * (total > 0 ? value / total : 0)), height: 4)
            }
            .frame(height: isHovering ? 6 : 4)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture { location in
                let fraction = max(0, min(1, location.x / geo.size.width))
                onSeek(fraction * total)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = max(0, min(1, drag.location.x / geo.size.width))
                        onSeek(fraction * total)
                    }
            )
        }
        .frame(height: 12)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

struct ControlButton: View {
    let systemName: String
    let size: Font
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Image(systemName: systemName)
            .font(size)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .opacity(isHovering ? 0.7 : 1.0)
            .onHover { isHovering = $0 }
            .onTapGesture { action() }
    }
}
