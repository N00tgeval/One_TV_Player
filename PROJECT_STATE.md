# One TV Player Project State

Last updated: 2026-06-05

## Goal

One TV Player is a neutral IPTV/FAST playlist player. The app should let users
add their own legal stream sources and optionally enable transparent public FAST
M3U presets. The app should not provide illegal, paid, grey-area, or bundled
content as a service.

The motivation is to avoid needing different IPTV apps on different devices and
to avoid basic player features being locked behind ads, subscriptions, or
premium walls.

## Product Positioning

- Neutral playlist/player app.
- No ads, paywalls, trackers, or bundled questionable content.
- Users manage their own sources.
- Optional public FAST presets are choices that users manually enable.
- Settings are local first, but should be structured so sync can be added later.
- UI should only show currently useful features.
- Movies, Series, and VOD can be first-level sections only when matching content
  exists and the flows are implemented.
- Adult content should be hideable or protected behind a local PIN when source
  metadata or category names make classification possible.

## App Identity

- Display name: One TV Player
- Flutter project/package name: `one_tv_player`
- Android application ID: `app.onetv.player`

The app name is provisional enough that branding can still change later.

## Target Platforms

Primary first target:

- Android TV / Google TV Streamer 4K

Planned Flutter targets:

- Android
- Android TV
- Windows
- iOS later, but iOS builds require macOS/Xcode

Possible later target:

- TizenOS/Samsung TV, likely as a separate investigation or separate web/Tizen
  app path. Do not let Tizen delay the Android TV MVP.

## Technical Stack

- Flutter / Dart
- Android Gradle Plugin 8.13.2
- Kotlin 2.3.21
- Player/runtime:
  - `video_player` for Android preview/fullscreen ExoPlayer-backed playback
  - `media_kit` packages remain in dependencies for now and should be reviewed
    during cleanup
- HTTP:
  - `http`
- Local settings:
  - `shared_preferences`
- Secure source credentials:
  - `flutter_secure_storage`
- Lints:
  - `flutter_lints`

## Current Repository State

Project directory on the active Windows development machine:

```text
C:\Users\sverb\Documents\one_tv_player
```

Flutter platform scaffolding currently exists for:

- Android
- Windows

Current implemented features:

- Android TV-first home screen.
- Compact left sidebar with Live TV, Refresh, Sources, and future destination
  placeholders hidden/disabled until useful.
- Category rail and channel grid.
- Strong focus states and D-pad navigation traps for key browsing sections.
- Live TV preview player while browsing.
- Fullscreen live player reuses the preview playback session when possible.
- Fullscreen OSD with back, previous/next, favorite, retry, and hide-channel
  actions.
- Up/down zapping in fullscreen playback.
- Channel search across loaded sources.
- Favorites.
- Hidden channels.
- Local settings/cache store.
- M3U/M3U8 parser.
- Channel model with live/movie/series content type hints.
- Playlist repository that downloads enabled sources.
- Merge and deduplicate channels across enabled sources.
- Samsung TV Plus country-variant deduplication by normalized channel name.
- Playback fallback URLs for Xtream channels with multiple server URLs.
- Optional public FAST presets:
  - Samsung TV Plus
  - Pluto TV
  - Plex TV
  - PBS
- Sources screen:
  - Add M3U
  - Add Xtream
  - Demo FAST provider list
  - Active sources list
  - Source detail screen
  - Refresh source
  - Enable/disable source
  - Delete source
  - Test source/server connectivity
- Xtream Codes support for live TV:
  - username/password
  - primary server URL
  - backup server URLs
  - fastest working server selection
  - per-server health tests
- Xtream-like URLs pasted into the M3U form are detected and moved to the
  Xtream form.
- Xtream passwords are stored via secure storage, not in source JSON.
- Android manifest adjusted for Android TV:
  - `LEANBACK_LAUNCHER`
  - touchscreen not required
  - internet permission
  - app label `One TV Player`

## Verification Already Run

Recent checks on the Windows development machine:

```powershell
flutter analyze
flutter test
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am start -W -n app.onetv.player/.MainActivity
```

Latest results:

- `flutter analyze`: no issues found.
- `flutter test`: 12 tests passed.
- Android debug APK builds successfully.
- APK deploys to the Android TV emulator.

Known warning:

- Some transitive plugins still apply the Kotlin Gradle Plugin directly:
  `package_info_plus`, `screen_brightness_android`, `volume_controller`,
  `wakelock_plus`. This is currently a warning, not a build blocker.

## Recommended Next Steps

1. Rename/edit existing sources.
2. Add/remove Xtream backup URLs from existing source detail.
3. Add clear cache and reset hidden channels actions.
4. Improve source loading/error copy and progress status.
5. Add basic XMLTV/EPG loading and now/next display.
6. Decide whether Movies/Series/VOD are part of the first MVP or remain hidden
   until the live TV experience is polished.
7. Continue Android TV remote testing on emulator and physical Google TV
   hardware.

## Roadmap

### Phase 1: Local MVP

- TV-first home screen.
- M3U/M3U8 URL sources.
- Xtream Codes source support for live TV.
- Optional public FAST presets.
- Playlist download and local cache.
- Merge and deduplicate multiple enabled sources.
- Local app settings.
- Favorites.
- Channel search across enabled sources.
- Live TV preview/mini-player flow before fullscreen playback.
- Fullscreen live player.
- Basic remote, keyboard, and touch navigation.
- Source management and source testing.

### Phase 2: Source and Settings Management

- Rename sources.
- Edit source details.
- Add/remove Xtream backup URLs after source creation.
- Clear playlist cache.
- Reset hidden channels.
- Per-source automatic refresh settings.
- Custom HTTP headers per source where needed, especially User-Agent.
- Preserve duplicate channel URLs as alternative/fallback streams more broadly.
- Import/export settings as a local file.
- Recently viewed live channels.
- Keep settings as one sync-ready model:
  - sources
  - content type preferences
  - language and subtitle filter preferences
  - adult content visibility and PIN settings
  - favorites
  - recently viewed
  - hidden groups
  - player preferences
  - UI preferences
  - last opened channel

### Phase 3: Settings Sync

- Sync settings across installed devices.
- Prefer pairing-code UX for TV devices.
- Avoid long account/login flows on TV.
- Store only app settings and source metadata, not content.
- Consider encrypted settings payloads before using a hosted backend.

### Phase 4: Guide and Provider Features

- XMLTV/EPG loading and cache.
- Now/next metadata in the channel list.
- Now/next metadata near the live preview mini-player.
- OSD with current program information.
- Player action bar with content-type-specific controls.
- Audio/subtitle selection where supported by the player/platform.
- External subtitle lookup for movies and series when reliable metadata is
  available.
- Embedded subtitle support for live streams where the stream/player exposes
  subtitle tracks.
- Aspect ratio options.
- Radio/audio playlist support if enough real sources need it.
- Catch-up/archive support where provider metadata supports it.

### Phase 5: Platform Expansion

- Polish Android TV and Google TV Streamer 4K first.
- Refine Android mobile, iOS, and Windows UX.
- Investigate TizenOS as a separate path later.

### Release Preparation

- Prepare store listing text before submitting to any store.
- Keep listing copy neutral: playlist/player app, not a content provider.
- Clearly state that users add their own legal sources.
- Avoid language that implies access to paid, pirated, or grey-area content.
- Prepare privacy policy and data safety answers.
- Prepare first-start legal/privacy notice inside the app.
