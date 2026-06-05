import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/playlist_source.dart';
import 'm3u_parser.dart';

class PlaylistRepository {
  PlaylistRepository({http.Client? client, M3uParser? parser})
      : _client = client ?? http.Client(),
        _parser = parser ?? M3uParser() {
    _xtreamClient = XtreamClient(_client);
  }

  final http.Client _client;
  final M3uParser _parser;
  late final XtreamClient _xtreamClient;

  Future<List<Channel>> loadChannels(List<PlaylistSource> sources) async {
    final channels = <Channel>[];
    for (final source in sources.where((source) => source.enabled)) {
      switch (source.type) {
        case PlaylistSourceType.m3uUrl:
        case PlaylistSourceType.fastPreset:
          final response = await _client.get(Uri.parse(source.url));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw PlaylistLoadException(source.name, response.statusCode);
          }
          channels.addAll(_parser.parse(response.body, sourceId: source.id));
        case PlaylistSourceType.xtream:
          channels.addAll(await _xtreamClient.loadLiveChannels(source));
      }
    }
    return deduplicateChannels(channels);
  }

  Future<SourceTestResult> testSource(PlaylistSource source) async {
    switch (source.type) {
      case PlaylistSourceType.m3uUrl:
      case PlaylistSourceType.fastPreset:
        final stopwatch = Stopwatch()..start();
        final response = await _client
            .get(Uri.parse(source.url))
            .timeout(const Duration(seconds: 10));
        stopwatch.stop();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return SourceTestResult(
            message: 'Playlist responded with HTTP ${response.statusCode}.',
            success: false,
            latency: stopwatch.elapsed,
          );
        }
        final channels = _parser.parse(response.body, sourceId: source.id);
        return SourceTestResult(
          message: channels.isEmpty
              ? 'Playlist loaded, but no channels were found.'
              : 'Playlist OK. ${channels.length} channels found.',
          success: channels.isNotEmpty,
          latency: stopwatch.elapsed,
        );
      case PlaylistSourceType.xtream:
        return _xtreamClient.testSource(source);
    }
  }

  List<Channel> deduplicateChannels(List<Channel> channels) {
    final byKey = <String, Channel>{};

    for (final channel in channels) {
      final key = _dedupeKey(channel);
      byKey.putIfAbsent(key, () => channel);
    }

    return byKey.values.toList();
  }

  String _dedupeKey(Channel channel) {
    if (channel.sourceId == 'samsung-tv-plus') {
      final name = channel.tvgName?.trim().isNotEmpty == true
          ? channel.tvgName!
          : channel.name;
      return 'samsung-tv-plus:${channel.contentType.name}:${_normalizeName(name)}';
    }

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

class XtreamSourceInput {
  const XtreamSourceInput({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;

  static XtreamSourceInput? tryParse(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final lowerPath = uri.path.toLowerCase();
    final hasXtreamPath =
        lowerPath.endsWith('/get.php') || lowerPath.endsWith('/player_api.php');
    final username = uri.queryParameters['username']?.trim();
    final password = uri.queryParameters['password']?.trim();
    if (!hasXtreamPath ||
        username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return XtreamSourceInput(
      serverUrl: XtreamClient.normalizeBaseUrl(uri).toString(),
      username: username,
      password: password,
    );
  }
}

class XtreamClient {
  XtreamClient(this._client);

  final http.Client _client;

  static Uri normalizeBaseUrl(Uri uri) {
    final pathSegments = uri.pathSegments
        .where((segment) =>
            segment.isNotEmpty &&
            segment.toLowerCase() != 'get.php' &&
            segment.toLowerCase() != 'player_api.php')
        .toList();
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: pathSegments,
    );
  }

  Future<List<Channel>> loadLiveChannels(PlaylistSource source) async {
    final username = source.username;
    final password = source.password;
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw XtreamLoadException(source.name, 'Missing username or password.');
    }

    final serverUrls = _candidateServerUrls(source);
    if (serverUrls.isEmpty) {
      throw XtreamLoadException(source.name, 'Missing server URL.');
    }

    final healthChecks = <_XtreamHealth>[];
    for (final serverUrl in serverUrls) {
      final health = await _checkHealth(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      if (health.isValid) healthChecks.add(health);
    }
    if (healthChecks.isEmpty) {
      throw XtreamLoadException(source.name, 'No working server URL found.');
    }

    healthChecks.sort((a, b) => a.latency.compareTo(b.latency));
    final bestBaseUrl = healthChecks.first.baseUrl;
    final categories = await _loadLiveCategories(
      baseUrl: bestBaseUrl,
      username: username,
      password: password,
    );
    final streams = await _loadLiveStreams(
      baseUrl: bestBaseUrl,
      username: username,
      password: password,
    );

    return [
      for (final stream in streams)
        if (stream['stream_id'] != null)
          _channelFromXtreamStream(
            source: source,
            stream: stream,
            healthChecks: healthChecks,
            categories: categories,
            username: username,
            password: password,
          ),
    ];
  }

  Future<SourceTestResult> testSource(PlaylistSource source) async {
    final username = source.username;
    final password = source.password;
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return const SourceTestResult(
        message: 'Missing username or password.',
        success: false,
      );
    }

    final serverUrls = _candidateServerUrls(source);
    if (serverUrls.isEmpty) {
      return const SourceTestResult(
        message: 'Missing server URL.',
        success: false,
      );
    }

    final servers = <SourceServerTestResult>[];
    for (final serverUrl in serverUrls) {
      final health = await _checkHealth(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      servers.add(
        SourceServerTestResult(
          url: health.baseUrl.toString(),
          success: health.isValid,
          latency: health.latency,
          message: health.isValid ? 'Login OK' : 'No valid login response',
        ),
      );
    }
    final workingServers = servers.where((server) => server.success).length;
    return SourceTestResult(
      message: workingServers == 0
          ? 'No working Xtream server URL found.'
          : '$workingServers of ${servers.length} server URLs work.',
      success: workingServers > 0,
      servers: servers,
    );
  }

  Channel _channelFromXtreamStream({
    required PlaylistSource source,
    required Map<String, Object?> stream,
    required List<_XtreamHealth> healthChecks,
    required Map<String, String> categories,
    required String username,
    required String password,
  }) {
    final streamId = stream['stream_id'].toString();
    final streamUrls = [
      for (final health in healthChecks)
        _buildLiveStreamUrl(
          baseUrl: health.baseUrl,
          username: username,
          password: password,
          streamId: streamId,
        ).toString(),
    ];
    return Channel(
      id: '${source.id}:$streamId',
      name: _stringValue(stream['name']) ?? 'Unnamed channel',
      url: streamUrls.first,
      group: categories[_stringValue(stream['category_id'])] ?? source.name,
      logoUrl: _stringValue(stream['stream_icon']),
      tvgId: _stringValue(stream['epg_channel_id']),
      tvgName: _stringValue(stream['name']),
      sourceId: source.id,
      streamUrls: streamUrls,
    );
  }

  List<String> _candidateServerUrls(PlaylistSource source) {
    final candidates = [
      if (source.lastWorkingBaseUrl != null) source.lastWorkingBaseUrl!,
      ...source.serverUrls,
      if (source.url.isNotEmpty) source.url,
    ];
    final seen = <String>{};
    final normalized = <String>[];
    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate.trim());
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        continue;
      }
      final baseUrl = normalizeBaseUrl(uri).toString();
      if (seen.add(baseUrl)) normalized.add(baseUrl);
    }
    return normalized;
  }

  Future<_XtreamHealth> _checkHealth({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final baseUrl = normalizeBaseUrl(Uri.parse(serverUrl));
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get(_playerApiUri(baseUrl, username, password))
          .timeout(const Duration(seconds: 6));
      stopwatch.stop();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _XtreamHealth.offline(baseUrl, stopwatch.elapsed);
      }
      final decoded = jsonDecode(response.body);
      final userInfo = decoded is Map<String, Object?>
          ? decoded['user_info'] as Map<String, Object?>?
          : null;
      final auth = userInfo?['auth'];
      final status = userInfo?['status']?.toString().toLowerCase();
      return _XtreamHealth(
        baseUrl: baseUrl,
        latency: stopwatch.elapsed,
        isValid: auth == 1 || status == 'active',
      );
    } catch (_) {
      stopwatch.stop();
      return _XtreamHealth.offline(baseUrl, stopwatch.elapsed);
    }
  }

  Future<Map<String, String>> _loadLiveCategories({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final response = await _client.get(
      _playerApiUri(
        baseUrl,
        username,
        password,
        action: 'get_live_categories',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return {};
    return {
      for (final item in decoded.whereType<Map>())
        if (item['category_id'] != null && item['category_name'] != null)
          item['category_id'].toString(): item['category_name'].toString(),
    };
  }

  Future<List<Map<String, Object?>>> _loadLiveStreams({
    required Uri baseUrl,
    required String username,
    required String password,
  }) async {
    final response = await _client.get(
      _playerApiUri(baseUrl, username, password, action: 'get_live_streams'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const XtreamLoadException('Xtream', 'Could not load live streams.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Uri _playerApiUri(
    Uri baseUrl,
    String username,
    String password, {
    String? action,
  }) {
    return baseUrl.replace(
      pathSegments: [...baseUrl.pathSegments, 'player_api.php'],
      queryParameters: {
        'username': username,
        'password': password,
        if (action != null) 'action': action,
      },
    );
  }

  Uri _buildLiveStreamUrl({
    required Uri baseUrl,
    required String username,
    required String password,
    required String streamId,
  }) {
    return baseUrl.replace(
      pathSegments: [
        ...baseUrl.pathSegments,
        'live',
        username,
        password,
        '$streamId.m3u8',
      ],
      query: null,
    );
  }

  static String? _stringValue(Object? value) {
    final string = value?.toString().trim();
    return string == null || string.isEmpty ? null : string;
  }
}

class _XtreamHealth {
  const _XtreamHealth({
    required this.baseUrl,
    required this.latency,
    required this.isValid,
  });

  factory _XtreamHealth.offline(Uri baseUrl, Duration latency) {
    return _XtreamHealth(baseUrl: baseUrl, latency: latency, isValid: false);
  }

  final Uri baseUrl;
  final Duration latency;
  final bool isValid;
}

class XtreamLoadException implements Exception {
  const XtreamLoadException(this.sourceName, this.reason);

  final String sourceName;
  final String reason;

  @override
  String toString() {
    return 'Could not load $sourceName: $reason';
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

class SourceTestResult {
  const SourceTestResult({
    required this.message,
    required this.success,
    this.latency,
    this.servers = const [],
  });

  final String message;
  final bool success;
  final Duration? latency;
  final List<SourceServerTestResult> servers;
}

class SourceServerTestResult {
  const SourceServerTestResult({
    required this.url,
    required this.message,
    required this.success,
    required this.latency,
  });

  final String url;
  final String message;
  final bool success;
  final Duration latency;
}
