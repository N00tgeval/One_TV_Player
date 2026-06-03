# One TV Player

One TV Player is a neutral IPTV/FAST playlist player. The app does not provide
paid or grey-area content. Users add their own sources, with optional public
FAST/M3U presets that can be enabled manually.

## MVP scope

- Add an M3U/M3U8 playlist URL.
- Offer optional public FAST presets.
- Cache playlists locally.
- Show channels grouped by playlist category.
- Save local settings and favorites.
- Play live streams fullscreen.
- Support TV remote, keyboard, and touch-friendly navigation.

## Product direction

The app should feel TV-first, closer to OTT Navigator or IPTV One than to a
generic mobile list app. Browsing should be fast, dense, and remote-friendly:

- Categories and favorites stay easy to reach.
- Channel browsing should work well with D-pad navigation.
- The selected item must always have a clear focus state.
- Playback should support an OSD and a channel-list overlay later.
- Settings should be powerful but not dominate the main viewing flow.

## Roadmap

### Phase 1: Local MVP

- TV-first home screen with categories on the left and channels on the right.
- M3U/M3U8 URL sources.
- Optional public FAST presets that the user manually enables.
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
- Structure settings as one sync-ready model:
  - sources
  - favorites
  - hidden groups
  - player preferences
  - UI preferences
  - last opened channel

### Phase 3: Settings Sync

- Sync settings across installed devices.
- Prefer pairing-code UX for TV devices.
- Keep long account/login flows off the TV where possible.
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

- Android TV and Google TV Streamer 4K polish first.
- Android mobile, iOS, and Windows UX refinement.
- TizenOS research as a separate web/Tizen app path if needed.

## Current workspace note

Flutter is not installed on this machine yet. After installing Flutter, generate
the native platform scaffolding from this directory:

```sh
flutter create --platforms=android,ios,windows .
flutter pub get
flutter test
flutter run
```

For Android TV, the generated Android manifest should be adjusted later with TV
launcher intent filters, leanback support, and remote-control testing on the
Google TV Streamer 4K.
