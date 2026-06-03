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

  Channel copyWith({String? sourceId}) {
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
    };
  }

  factory Channel.fromJson(Map<String, Object?> json) {
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
    );
  }
}
