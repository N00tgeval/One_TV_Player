# Changelog

## 0.1.0 - 2026-06-05

### Added

- Android TV-first live TV layout with compact left sidebar, category rail, and
  channel grid.
- Strong D-pad focus states and focus containment for key browsing sections.
- Public FAST presets per provider:
  - Samsung TV Plus
  - Pluto TV
  - Plex TV
  - PBS
- M3U/M3U8 source flow.
- Xtream Codes source flow with username/password, primary server URL, and
  backup server URLs.
- Automatic detection of Xtream-like `get.php` / `player_api.php` URLs pasted
  into the M3U form.
- Secure Xtream password storage via `flutter_secure_storage`.
- Source detail screen with refresh, enable/disable, delete, and source/server
  testing.
- Per-source test results, including Xtream server URL health and latency.
- Search across loaded channels.
- Favorites and hidden channels.
- Live TV preview player while browsing.
- Fullscreen live player that can reuse the active preview session.
- Fullscreen OSD with back, previous/next, favorite, retry, and hide-channel
  actions.
- Channel zapping in fullscreen playback.
- Playback fallback URL support for Xtream channels.
- Android TV manifest configuration and app id `app.onetv.player`.
- Source navigation wireframe mockup for the sidebar/sources direction.

### Changed

- Replaced the broad demo FAST shortcut with an explicit FAST provider picker.
- Switched Android playback flow to an ExoPlayer-backed `video_player` session
  for preview/fullscreen continuity.
- Updated Android Gradle/Kotlin configuration for the current local toolchain.
- Improved playlist deduplication, including Samsung TV Plus country variants.
- Updated project documentation to reflect the current Windows/Android TV
  development state.

### Fixed

- Source type switching now updates the visible add form when moving between
  M3U, Xtream, and FAST choices.
- FAST provider rows are now TV-focusable and visibly selected.
- Back navigation in Sources returns to the previous submenu before leaving the
  Sources screen.
- Focus no longer leaks from source panels into unrelated sections at list
  edges.
- Search query is cleared when returning to normal category browsing.
- Fullscreen playback no longer rebuffers when opening from an active preview
  session for the same channel.

### Known Issues

- Some transitive plugins still apply the Kotlin Gradle Plugin directly. This
  currently produces a build warning but does not block Android debug builds.
- Movies, Series, VOD, EPG, and settings sync are not MVP-complete yet.
