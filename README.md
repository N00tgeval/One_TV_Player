# One TV Player

One TV Player is a neutral IPTV/FAST playlist player. The app does not provide
paid or grey-area content. Users add their own sources, with optional public
FAST/M3U presets that can be enabled manually.

## MVP scope

- Add an M3U/M3U8 playlist URL.
- Add Xtream Codes credentials as a primary source type.
- Offer optional public FAST presets.
- Cache playlists locally.
- Merge multiple enabled sources into one library.
- Deduplicate overlapping channels from multiple FAST/M3U sources.
- Allow a source/provider to define multiple server/base URLs when offered, so
  playback and metadata requests can fail over to another endpoint.
- Show channels grouped by playlist category.
- Save local settings and favorites.
- Search channels across enabled sources.
- Play live streams fullscreen.
- Support TV remote, keyboard, and touch-friendly navigation.

## Product direction

The app should feel TV-first, closer to OTT Navigator or IPTV One than to a
generic mobile list app. Browsing should be fast, dense, and remote-friendly:

- Categories and favorites stay easy to reach.
- Channel browsing should work well with D-pad navigation.
- The selected item must always have a clear focus state.
- The left icon sidebar should stay compact while browsing, then expand with
  text labels when focus moves into it.
- Playback should support an OSD and a channel-list overlay later.
- Playback controls should show an action bar on pause/OK/menu with actions
  adapted to the current content type.
- Live TV browsing should support a preview flow: selecting a channel starts a
  mini-player, while a second OK opens fullscreen playback.
- Mini-player preview is only for live TV browsing. Movies, Series, and VOD
  should use detail/play flows instead.
- Series should use a season/episode detail flow: poster/artwork, season list,
  episode list, playback area, and metadata should stay visible without forcing
  fullscreen first.
- When EPG data is available, now/next program information should be shown near
  the mini-player during browsing.
- Settings should be powerful but not dominate the main viewing flow.
- Do not show disabled placeholder sections. If a feature has no current value,
  keep it out of the UI until it works.
- Show Movies and Series as first-level destinations only when the active
  sources contain matching content.
- For non-live content, support language/subtitle preference filters when the
  source metadata is reliable enough.
- Adult content should be hideable or protected behind a local PIN when source
  metadata or category names make classification possible.

## Roadmap

### Phase 1: Local MVP

- TV-first home screen with categories on the left and channels on the right.
- Collapsible left sidebar: icon-only by default, expanded with labels when
  focused.
- M3U/M3U8 URL sources.
- Xtream Codes source support for live TV, movies, series, and richer metadata.
- Optional public FAST presets that the user manually enables.
- Playlist download and local cache.
- Merge and deduplicate multiple enabled sources.
- Local app settings.
- Favorites.
- Channel search across enabled sources.
- Basic live TV, movies, and series detection where playlist metadata is clear.
- Live TV preview/mini-player flow before fullscreen playback.
- Fullscreen live player.
- Basic remote, keyboard, and touch navigation.

### Player Action Bar

- Show when playback is paused or when OK/Menu opens the OSD.
- Keep actions icon-first and D-pad friendly.
- Common actions:
  - favorite/unfavorite
  - audio track
  - subtitles
  - aspect ratio
  - stream info
- Live TV actions:
  - previous/next channel
  - open channel list overlay
  - open guide/now-next when available
- Series actions:
  - previous episode
  - next episode
  - open season/episode list
  - mark watched/resume later
- Movie/VOD actions:
  - resume/restart
  - mark watched
  - open details

### Phase 2: Source and Settings Management

- Hide/show groups.
- Filter Movies, Series, and VOD by preferred audio/subtitle languages where
  metadata supports it.
- Series detail layout with poster/artwork, seasons, episodes, playback area,
  and episode metadata.
- Hide or PIN-protect adult categories/content.
- Automatic source refresh on app startup, with per-source refresh settings.
- Custom HTTP headers per source where needed, especially User-Agent.
- Rename sources.
- Enable/disable sources.
- Delete sources.
- Clear playlist cache.
- Preserve duplicate channel URLs as alternative/fallback streams instead of
  only dropping duplicates.
- Support multiple server/base URLs per provider where available, especially
  for Xtream-style sources.
- Import/export settings as a local file.
- Recently viewed live channels.
- Structure settings as one sync-ready model:
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
- Keep long account/login flows off the TV where possible.
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

- Android TV and Google TV Streamer 4K polish first.
- Android mobile, iOS, and Windows UX refinement.
- TizenOS research as a separate web/Tizen app path if needed.

### Release Preparation

- Prepare store listing text before submitting to any store.
- Keep listing copy neutral: playlist/player app, not a content provider.
- Clearly state that users add their own legal sources.
- Avoid language that implies access to paid, pirated, or grey-area content.
- Prepare privacy policy and data safety answers.
- Prepare first-start legal/privacy notice inside the app.

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
