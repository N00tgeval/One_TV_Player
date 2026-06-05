# One TV Player

One TV Player is a neutral IPTV/FAST playlist player. The app does not provide
paid, pirated, grey-area, or bundled content as a service. Users add their own
legal sources, with optional public FAST presets that can be enabled manually.

## Current MVP Status

The current build is Android TV-first and focuses on live TV playback:

- TV-first home layout with compact left sidebar, categories, channel grid, and
  strong D-pad focus states.
- Live TV preview player while browsing; pressing OK again opens fullscreen
  playback without rebuffering the same channel.
- Fullscreen player with OSD, previous/next channel zapping, retry, favorite,
  and hide-channel actions.
- Channel search across loaded sources.
- Favorites and hidden channels.
- Public FAST presets exposed per provider.
- M3U/M3U8 source support.
- Xtream Codes live TV source support with multiple server URLs.
- Xtream-like `get.php` / `player_api.php` URLs entered in the M3U form are
  detected and moved into the Xtream flow.
- Source management: refresh, enable/disable, delete, and test source/server
  connectivity.
- Secure Xtream password storage via platform secure storage.
- Local settings and channel cache.
- Android TV manifest and build configuration.

Movies, Series, VOD, EPG, settings sync, and iOS/Windows polish are planned but
not finished MVP features yet.

## FAST Presets

FAST presets are optional and user-enabled. The current demo providers are:

- Samsung TV Plus
- Pluto TV
- Plex TV
- PBS

These are public playlist presets for development/demo use. They are kept as
separate providers instead of one large aggregator playlist so testing and
source management stay understandable.

## Source Types

### M3U/M3U8

Users can add a playlist URL directly. The app downloads, parses, caches, and
deduplicates channels across enabled sources.

### Xtream Codes

Users can add:

- source name
- primary server URL
- optional backup server URLs
- username
- password

Xtream passwords are not written into the JSON settings payload. They are stored
through `flutter_secure_storage`. Each configured server URL can be tested from
the source detail screen.

## Product Direction

The app should feel TV-first, closer to OTT Navigator or IPTV One than to a
generic mobile list app:

- Browsing should be fast, dense, and remote-friendly.
- The selected item must always have a clear focus state.
- Categories and favorites should stay easy to reach.
- Live TV uses a preview flow before fullscreen playback.
- Movies, Series, and VOD should use detail/play flows instead of the live TV
  browse layout.
- Settings should be powerful but not dominate the main viewing flow.
- Disabled placeholder sections should stay out of the UI until they work.
- Adult content should later be hideable or protected behind a local PIN when
  source metadata makes classification possible.

## Development

From the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Deploy to a connected Android device or emulator:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am start -W -n app.onetv.player/.MainActivity
```

The current Android application ID is:

```text
app.onetv.player
```

## Roadmap

### MVP Remaining

- Rename/edit existing sources.
- Add/remove Xtream backup URLs from existing sources.
- Clear cache and reset hidden channels from settings.
- Improve loading and error messages during source refresh.
- Add basic EPG/XMLTV support for now/next data.
- Decide whether Movies/Series/VOD are in the first MVP or remain hidden until
  the live TV flow is fully polished.

### Later

- Rich Movies/Series/VOD navigation.
- EPG guide screen and OSD program information.
- Audio/subtitle/aspect controls where the platform exposes them.
- Recently viewed channels.
- Import/export settings.
- Settings sync with TV-friendly pairing-code UX.
- Android mobile, Windows, and iOS layout refinement.
- TizenOS research as a separate path if needed.

## Release Notes

See [CHANGELOG.md](CHANGELOG.md).
