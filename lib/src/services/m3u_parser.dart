import '../models/channel.dart';

class M3uParser {
  List<Channel> parse(String content, {String? sourceId}) {
    final channels = <Channel>[];
    final lines = content.split(RegExp(r'\r?\n'));
    _PendingChannel? pending;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        pending = _parseExtInf(line);
        continue;
      }

      if (line.startsWith('#')) continue;

      if (pending != null) {
        final id = _stableId(sourceId, pending.name, line);
        channels.add(
          Channel(
            id: id,
            name: pending.name,
            url: line,
            contentType: _inferContentType(pending.group),
            group: pending.group,
            logoUrl: pending.logoUrl,
            tvgId: pending.tvgId,
            tvgName: pending.tvgName,
            sourceId: sourceId,
          ),
        );
        pending = null;
      }
    }

    return channels;
  }

  _PendingChannel _parseExtInf(String line) {
    final commaIndex = line.indexOf(',');
    final attributes =
        commaIndex == -1 ? line : line.substring(0, commaIndex).trim();
    final title = commaIndex == -1
        ? 'Unnamed channel'
        : line.substring(commaIndex + 1).trim();

    return _PendingChannel(
      name: title.isEmpty ? 'Unnamed channel' : title,
      group: _attribute(attributes, 'group-title') ?? 'Other',
      logoUrl: _attribute(attributes, 'tvg-logo'),
      tvgId: _attribute(attributes, 'tvg-id'),
      tvgName: _attribute(attributes, 'tvg-name'),
    );
  }

  String? _attribute(String input, String key) {
    final match = RegExp('$key="([^"]*)"').firstMatch(input);
    return match?.group(1)?.trim();
  }

  String _stableId(String? sourceId, String name, String url) {
    return '${sourceId ?? 'local'}:${name.trim().toLowerCase()}:${url.hashCode}';
  }

  ContentType _inferContentType(String group) {
    final normalized = group.toLowerCase();
    if (normalized.contains('series') ||
        normalized.contains('serie') ||
        normalized.contains('shows')) {
      return ContentType.series;
    }
    if (normalized.contains('movies') ||
        normalized.contains('movie') ||
        normalized.contains('films') ||
        normalized.contains('film') ||
        normalized.contains('vod')) {
      return ContentType.movie;
    }
    return ContentType.live;
  }
}

class _PendingChannel {
  const _PendingChannel({
    required this.name,
    required this.group,
    this.logoUrl,
    this.tvgId,
    this.tvgName,
  });

  final String name;
  final String group;
  final String? logoUrl;
  final String? tvgId;
  final String? tvgName;
}
