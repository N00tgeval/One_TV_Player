enum ContentType { live, movie, series }

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.url,
    this.contentType = ContentType.live,
    this.group = 'Other',
    this.logoUrl,
    this.tvgId,
    this.tvgName,
    this.sourceId,
    this.streamUrls = const [],
  });

  final String id;
  final String name;
  final String url;
  final ContentType contentType;
  final String group;
  final String? logoUrl;
  final String? tvgId;
  final String? tvgName;
  final String? sourceId;
  final List<String> streamUrls;

  Channel copyWith({String? sourceId, List<String>? streamUrls}) {
    return Channel(
      id: id,
      name: name,
      url: url,
      contentType: contentType,
      group: group,
      logoUrl: logoUrl,
      tvgId: tvgId,
      tvgName: tvgName,
      sourceId: sourceId ?? this.sourceId,
      streamUrls: streamUrls ?? this.streamUrls,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'contentType': contentType.name,
      'group': group,
      'logoUrl': logoUrl,
      'tvgId': tvgId,
      'tvgName': tvgName,
      'sourceId': sourceId,
      'streamUrls': streamUrls,
    };
  }

  factory Channel.fromJson(Map<String, Object?> json) {
    final rawStreamUrls = json['streamUrls'];
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      contentType: ContentType.values.byName(
        json['contentType'] as String? ?? ContentType.live.name,
      ),
      group: json['group'] as String? ?? 'Other',
      logoUrl: json['logoUrl'] as String?,
      tvgId: json['tvgId'] as String?,
      tvgName: json['tvgName'] as String?,
      sourceId: json['sourceId'] as String?,
      streamUrls: rawStreamUrls is List
          ? rawStreamUrls.whereType<String>().toList()
          : const [],
    );
  }
}
