enum PlaylistSourceType { m3uUrl, fastPreset, xtream }

class PlaylistSource {
  const PlaylistSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.enabled = true,
    this.serverUrls = const [],
    this.username,
    this.password,
    this.lastWorkingBaseUrl,
  });

  final String id;
  final String name;
  final String url;
  final PlaylistSourceType type;
  final bool enabled;
  final List<String> serverUrls;
  final String? username;
  final String? password;
  final String? lastWorkingBaseUrl;

  PlaylistSource copyWith({
    bool? enabled,
    List<String>? serverUrls,
    String? username,
    String? password,
    String? lastWorkingBaseUrl,
  }) {
    return PlaylistSource(
      id: id,
      name: name,
      url: url,
      type: type,
      enabled: enabled ?? this.enabled,
      serverUrls: serverUrls ?? this.serverUrls,
      username: username ?? this.username,
      password: password ?? this.password,
      lastWorkingBaseUrl: lastWorkingBaseUrl ?? this.lastWorkingBaseUrl,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type.name,
      'enabled': enabled,
      'serverUrls': serverUrls,
      'username': username,
      'lastWorkingBaseUrl': lastWorkingBaseUrl,
    };
  }

  factory PlaylistSource.fromJson(Map<String, Object?> json) {
    final rawServerUrls = json['serverUrls'];
    return PlaylistSource(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      type: PlaylistSourceType.values.byName(json['type'] as String),
      enabled: json['enabled'] as bool? ?? true,
      serverUrls: rawServerUrls is List
          ? rawServerUrls.whereType<String>().toList()
          : const [],
      username: json['username'] as String?,
      password: json['password'] as String?,
      lastWorkingBaseUrl: json['lastWorkingBaseUrl'] as String?,
    );
  }
}

const fastPresets = [
  PlaylistSource(
    id: 'samsung-tv-plus',
    name: 'Samsung TV Plus',
    url: 'https://i.mjh.nz/SamsungTVPlus/all.m3u8',
    type: PlaylistSourceType.fastPreset,
    enabled: false,
  ),
  PlaylistSource(
    id: 'pluto-tv',
    name: 'Pluto TV',
    url: 'https://i.mjh.nz/PlutoTV/all.m3u8',
    type: PlaylistSourceType.fastPreset,
    enabled: false,
  ),
  PlaylistSource(
    id: 'plex-tv',
    name: 'Plex TV',
    url: 'https://i.mjh.nz/Plex/all.m3u8',
    type: PlaylistSourceType.fastPreset,
    enabled: false,
  ),
  PlaylistSource(
    id: 'pbs',
    name: 'PBS',
    url: 'https://i.mjh.nz/PBS/all.m3u8',
    type: PlaylistSourceType.fastPreset,
    enabled: false,
  ),
];
