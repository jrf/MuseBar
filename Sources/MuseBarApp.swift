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

// MARK: - Player View

struct PlayerView: View {
    @ObservedObject var nowPlaying: NowPlayingManager

    var body: some View {
        VStack(spacing: 0) {
            if let track = nowPlaying.track {
                // Large artwork
                artworkView(track: track)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                // Track info (centered)
                VStack(spacing: 2) {
                    Text(track.title)
                        .font(.system(.title3, weight: .semibold))
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let album = track.album {
                        Text(album)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture { nowPlaying.revealInMusic() }
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                // Progress bar
                if nowPlaying.duration > 0 {
                    VStack(spacing: 4) {
                        SeekBar(
                            value: nowPlaying.elapsed,
                            total: nowPlaying.duration,
                            tint: .accentColor
                        ) { position in
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
                    .padding(.top, 12)
                }

                // Playback controls
                HStack(spacing: 28) {
                    ControlButton(systemName: "backward.fill", size: 22) {
                        nowPlaying.previousTrack()
                    }
                    PlayPauseButton(isPlaying: nowPlaying.isPlaying) {
                        nowPlaying.togglePlayPause()
                    }
                    ControlButton(systemName: "forward.fill", size: 22) {
                        nowPlaying.nextTrack()
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 14)

            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text("Nothing playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Play something in Music")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }

            // Settings + Quit
            HStack {
                SettingsMenu(nowPlaying: nowPlaying)
                Spacer()
                QuitButton()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private func artworkView(track: Track) -> some View {
        if let artwork = track.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 268, height: 268)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(width: 268, height: 268)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Seek Bar

struct SeekBar: View {
    let value: Double
    let total: Double
    let tint: Color
    let onSeek: (Double) -> Void

    @State private var isHovering = false

    private var fraction: Double {
        total > 0 ? value / total : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * fraction))

                // Thumb indicator on hover
                if isHovering {
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                        .shadow(color: tint.opacity(0.4), radius: 3)
                        .offset(x: max(0, min(geo.size.width - 10, geo.size.width * fraction - 5)))
                }
            }
            .frame(height: isHovering ? 6 : 4)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture { location in
                let frac = max(0, min(1, location.x / geo.size.width))
                onSeek(frac * total)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let frac = max(0, min(1, drag.location.x / geo.size.width))
                        onSeek(frac * total)
                    }
            )
        }
        .frame(height: 12)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Play/Pause Button (prominent)

struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.primary.opacity(isHovering ? 0.15 : 0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .offset(x: isPlaying ? 0 : 1) // optical centering for play icon
            }
            .contentShape(Circle())
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Control Button (prev/next)

struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .opacity(isHovering ? 0.7 : 1.0)
            .onHover { isHovering = $0 }
            .onTapGesture { action() }
    }
}

// MARK: - Settings Menu

struct SettingsMenu: View {
    @ObservedObject var nowPlaying: NowPlayingManager

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(NowPlayingManager.ControlBackend.allCases, id: \.self) { backend in
                Button {
                    nowPlaying.controlBackend = backend
                } label: {
                    HStack {
                        Text(backend.rawValue)
                        if nowPlaying.controlBackend == backend {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.caption)
                .foregroundStyle(isHovering ? .primary : .quaternary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(.primary.opacity(isHovering ? 0.08 : 0))
                )
                .contentShape(Circle())
                .onHover { hovering in
                    isHovering = hovering
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Quit Button

struct QuitButton: View {
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "power")
            .font(.caption)
            .foregroundStyle(isHovering ? .primary : .quaternary)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(.primary.opacity(isHovering ? 0.08 : 0))
            )
            .contentShape(Circle())
            .onHover { hovering in
                isHovering = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture { NSApplication.shared.terminate(nil) }
            .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
