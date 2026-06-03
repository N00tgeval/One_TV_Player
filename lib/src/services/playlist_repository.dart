import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/playlist_source.dart';
import 'm3u_parser.dart';

class PlaylistRepository {
  PlaylistRepository({http.Client? client, M3uParser? parser})
      : _client = client ?? http.Client(),
        _parser = parser ?? M3uParser();

  final http.Client _client;
  final M3uParser _parser;

  Future<List<Channel>> loadChannels(List<PlaylistSource> sources) async {
    final channels = <Channel>[];
    for (final source in sources.where((source) => source.enabled)) {
      final response = await _client.get(Uri.parse(source.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PlaylistLoadException(source.name, response.statusCode);
      }
      channels.addAll(_parser.parse(response.body, sourceId: source.id));
    }
    return _deduplicate(channels);
  }

  List<Channel> _deduplicate(List<Channel> channels) {
    final byKey = <String, Channel>{};

    for (final channel in channels) {
      final key = _dedupeKey(channel);
      byKey.putIfAbsent(key, () => channel);
    }

    return byKey.values.toList();
  }

  String _dedupeKey(Channel channel) {
    final tvgId = channel.tvgId?.trim().toLowerCase();
    if (tvgId != null && tvgId.isNotEmpty) {
      return 'tvg-id:${channel.contentType.name}:$tvgId';
    }

    final tvgName = channel.tvgName?.trim().toLowerCase();
    if (tvgName != null && tvgName.isNotEmpty) {
      return 'tvg-name:${channel.contentType.name}:$tvgName';
    }

    return 'name:${channel.contentType.name}:${_normalizeName(channel.name)}';
  }

  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*(hd|fhd|uhd|4k)\s*$'), '')
        .trim();
  }
}

class PlaylistLoadException implements Exception {
  const PlaylistLoadException(this.sourceName, this.statusCode);

  final String sourceName;
  final int statusCode;

  @override
  String toString() {
    return 'Could not load $sourceName (HTTP $statusCode).';
  }
}
