import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/channel.dart';
import '../models/playlist_source.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.sources,
    required this.cachedChannels,
    required this.favoriteChannelIds,
    required this.hiddenChannelIds,
    this.lastChannelId,
  });

  final List<PlaylistSource> sources;
  final List<Channel> cachedChannels;
  final Set<String> favoriteChannelIds;
  final Set<String> hiddenChannelIds;
  final String? lastChannelId;
}

class SettingsStore {
  SettingsStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _sourcesKey = 'sources';
  static const _channelsKey = 'cached_channels';
  static const _favoritesKey = 'favorite_channel_ids';
  static const _hiddenChannelsKey = 'hidden_channel_ids';
  static const _lastChannelKey = 'last_channel_id';

  Future<SettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final sourcesJson = prefs.getString(_sourcesKey);
    final channelsJson = prefs.getString(_channelsKey);

    final sources = sourcesJson == null
        ? <PlaylistSource>[]
        : (jsonDecode(sourcesJson) as List)
            .cast<Map<String, Object?>>()
            .map(PlaylistSource.fromJson)
            .toList();
    final hydratedSources = <PlaylistSource>[];
    var migratedLegacyPassword = false;
    for (final source in sources) {
      if (source.type != PlaylistSourceType.xtream) {
        hydratedSources.add(source);
        continue;
      }
      final storedPassword = await _secureStorage.read(
        key: _passwordKey(source.id),
      );
      final legacyPassword = source.password;
      final password = storedPassword ?? legacyPassword;
      if (storedPassword == null && legacyPassword != null) {
        await _secureStorage.write(
          key: _passwordKey(source.id),
          value: legacyPassword,
        );
        migratedLegacyPassword = true;
      }
      hydratedSources.add(source.copyWith(password: password));
    }
    if (migratedLegacyPassword) {
      await saveSources(hydratedSources);
    }

    final channels = channelsJson == null
        ? <Channel>[]
        : (jsonDecode(channelsJson) as List)
            .cast<Map<String, Object?>>()
            .map(Channel.fromJson)
            .toList();

    return SettingsSnapshot(
      sources: hydratedSources,
      cachedChannels: channels,
      favoriteChannelIds: prefs.getStringList(_favoritesKey)?.toSet() ?? {},
      hiddenChannelIds: prefs.getStringList(_hiddenChannelsKey)?.toSet() ?? {},
      lastChannelId: prefs.getString(_lastChannelKey),
    );
  }

  Future<void> saveSources(List<PlaylistSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final xtreamSourceIds = sources
        .where((source) => source.type == PlaylistSourceType.xtream)
        .map((source) => source.id)
        .toSet();
    final storedKeys = await _secureStorage.readAll();
    for (final source in sources) {
      final password = source.password;
      if (source.type == PlaylistSourceType.xtream &&
          password != null &&
          password.isNotEmpty) {
        await _secureStorage.write(
          key: _passwordKey(source.id),
          value: password,
        );
      }
    }
    for (final key in storedKeys.keys.where(_isPasswordKey)) {
      final sourceId = key.substring(_passwordKeyPrefix.length);
      if (!xtreamSourceIds.contains(sourceId)) {
        await _secureStorage.delete(key: key);
      }
    }
    await prefs.setString(
      _sourcesKey,
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
  }

  Future<void> saveChannels(List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _channelsKey,
      jsonEncode(channels.map((channel) => channel.toJson()).toList()),
    );
  }

  Future<void> saveFavorites(Set<String> channelIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, channelIds.toList()..sort());
  }

  Future<void> saveHiddenChannels(Set<String> channelIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenChannelsKey, channelIds.toList()..sort());
  }

  Future<void> saveLastChannel(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastChannelKey, channelId);
  }

  static const _passwordKeyPrefix = 'source_password_';

  String _passwordKey(String sourceId) => '$_passwordKeyPrefix$sourceId';

  bool _isPasswordKey(String key) => key.startsWith(_passwordKeyPrefix);
}
