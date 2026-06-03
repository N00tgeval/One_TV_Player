# One TV Player Project State

Last updated: 2026-06-03

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
- Optional public FAST presets can be shown as choices, but should be manually
  enabled by the user.
- Settings are local first, but should be structured so sync can be added later.

## App Name

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

- Flutter 3.44.1 was installed manually in WSL at:
  `/home/stefan/development/flutter`
- Dart 3.12.1
- Player package:
  - `media_kit`
  - `media_kit_video`
  - `media_kit_libs_video`
- HTTP:
  - `http`
- Local settings:
  - `shared_preferences`
- Lints:
  - `flutter_lints`

## Current Repository State

Project directory:

```sh
/home/stefan/one_tv_player
```

Flutter platform scaffolding has been generated for:

- Android
- Windows

Current implemented features:

- Basic Flutter app shell.
- Dark Material 3 theme.
- M3U/M3U8 parser.
- Playlist source model.
- Channel model.
- Local settings/cache store.
- Playlist repository that downloads enabled sources.
- Optional FAST presets:
  - IPTV-org public playlist
  - Free-TV public playlist
- Home screen with category rail and channel grid.
- Add M3U URL screen.
- Enable/disable public FAST presets.
- Favorites.
- Fullscreen live player screen using `media_kit`.
- Android manifest adjusted for Android TV:
  - `LEANBACK_LAUNCHER`
  - touchscreen not required
  - app label `One TV Player`

## Verification Already Run

From `/home/stefan/one_tv_player`:

```sh
/home/stefan/development/flutter/bin/flutter pub get
/home/stefan/development/flutter/bin/flutter test
/home/stefan/development/flutter/bin/flutter analyze
```

Results:

- `flutter test`: all tests passed.
- `flutter analyze`: no issues found.

Current tests:

- `test/m3u_parser_test.dart`
- `test/app_smoke_test.dart`

## Current Blocker

The current laptop is WSL2 and does not have the Android SDK/toolchain available.
Android Studio could not be installed successfully here.

`flutter doctor` reported:

- Flutter is OK.
- Android toolchain missing: unable to locate Android SDK.
- Chrome missing.
- Linux desktop build tools missing.

For Android TV development, continue on a machine where Android Studio and the
Android SDK can be installed normally.

## Setup On New Laptop

Install:

- Git
- Flutter SDK
- Android Studio
- Android SDK, Platform Tools, Build Tools
- VS Code + Flutter extension if desired
- Codex

Then from the project directory:

```sh
flutter pub get
flutter doctor
flutter test
flutter analyze
flutter devices
```

Once an Android TV device or emulator is visible:

```sh
flutter run
```

## Recommended Next Steps

1. Move the project to a git repository and push it to GitHub/GitLab.
2. Continue on a laptop with a working Android SDK.
3. Run `flutter doctor` until Android toolchain is green.
4. Deploy to Google TV Streamer 4K.
5. Test remote/D-pad navigation.
6. Replace the current basic channel grid with a more OTT Navigator/IPTV One
   style TV-first layout:
   - categories/groups on the left
   - channels on the right
   - strong focus states
   - favorites near the top
   - fast browsing with D-pad
7. Add source management:
   - rename source
   - remove source
   - enable/disable source
   - refresh source
   - clear cache
8. Add import/export settings before cloud sync.
9. Add settings sync later using a TV-friendly pairing-code flow.

## Roadmap

### Phase 1: Local MVP

- TV-first home screen.
- M3U/M3U8 URL sources.
- Optional public FAST presets.
- Playlist download and local cache.
- Local app settings.
- Favorites.
- Fullscreen live player.
- Basic remote, keyboard, and touch navigation.

### Phase 2: Source and Settings Management

- Hide/show groups.
- Rename sources.
- Enable/disable sources.
- Delete sources.
- Clear playlist cache.
- Import/export settings as a local file.
- Keep settings as one sync-ready model:
  - sources
  - favorites
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

- Xtream Codes login.
- XMLTV/EPG loading and cache.
- Now/next metadata in the channel list.
- OSD with current program information.
- Audio/subtitle selection where supported by the player/platform.
- Aspect ratio options.

### Phase 5: Platform Expansion

- Polish Android TV and Google TV Streamer 4K first.
- Refine Android mobile, iOS, and Windows UX.
- Investigate TizenOS as a separate path later.
