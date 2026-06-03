enum PlaylistSourceType { m3uUrl, fastPreset }

class PlaylistSource {
  const PlaylistSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String url;
  final PlaylistSourceType type;
  final bool enabled;

  PlaylistSource copyWith({bool? enabled}) {
    return PlaylistSource(
      id: id,
      name: name,
      url: url,
      type: type,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type.name,
      'enabled': enabled,
    };
  }

  factory PlaylistSource.fromJson(Map<String, Object?> json) {
    return PlaylistSource(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      type: PlaylistSourceType.values.byName(json['type'] as String),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

const fastPresets = [
  PlaylistSource(
    id: 'iptv-org',
    name: 'IPTV-org public channels',
    url: 'https://iptv-org.github.io/iptv/index.m3u',
    type: PlaylistSourceType.fastPreset,
    enabled: false,
  ),
  PlaylistSource(
    id: 'free-tv',
    name: 'Free-TV public channels',
    url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8',
    type: PlaylistSourceType.fastPreset,
    enabled: false,
  ),
];
