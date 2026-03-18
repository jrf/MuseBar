# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MuseBar is a lightweight macOS menu bar app (SwiftUI) that displays the currently playing track from Apple Music, with optional Spotify and Muse CLI backends. No Dock icon — lives entirely in the menu bar. Pure Swift, no external dependencies.

## Build Commands

Uses [just](https://github.com/casey/just) command runner. Swift Package Manager for compilation.

| Command | What it does |
|---------|-------------|
| `just` | Build release, package .app, install to ~/Applications, launch |
| `just build` | Build release binary + create .app bundle in `build/` |
| `just run` | Build and run from terminal (kills previous instance first) |
| `just debug` | Build debug binary only (no .app bundle) |
| `just clean` | Remove `.build/` and `build/` directories |
| `just install` | Build, install to ~/Applications, codesign, launch |

Build targets arm64 (Apple Silicon), macOS 13+, Swift 5.9+.

## Architecture

Two source files with clean separation:

- **`Sources/NowPlayingManager.swift`** — `@MainActor` observable class that owns all playback state (`track`, `isPlaying`, `elapsed`, `duration`). Manages three control backends (AppleScript, Muse CLI, Spotify) and receives track changes via `com.apple.Music.playerInfo` distributed notifications plus a 0.5s polling timer for progress.

- **`Sources/MuseBarApp.swift`** — `@main` entry point using `MenuBarExtra` with `.window` style. Contains all UI: `PlayerView` (main dropdown), `SeekBar` (drag/tap progress), playback controls, `SettingsMenu` (backend picker), and quit button.

### Music Integration

1. **AppleScript** (default) — queries Music.app for track info, artwork, position; sends playback commands
2. **Distributed Notifications** — `com.apple.Music.playerInfo` for real-time track change events
3. **Muse CLI** (`~/.local/bin/muse`) — optional backend for play/next/prev commands
4. **Spotify** — AppleScript control of Spotify.app

### Key Patterns

- Generation counter on async AppleScript calls to discard stale results (race condition guard)
- Cached playback position + time delta for smooth progress bar between timer ticks
- 2-second grace period suppresses spurious "Stopped" state during Muse CLI track transitions
- Backend choice persisted in UserDefaults

## Resources

- `Resources/Info.plist` — macOS bundle config (LSUIElement=true hides Dock icon)
- `Resources/AppIcon.icns` — app icon

## No Tests

There is no test suite. Manual testing via `just run`.
