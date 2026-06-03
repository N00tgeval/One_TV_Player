import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/playlist_source.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.sources,
    required this.cachedChannels,
    required this.favoriteChannelIds,
    this.lastChannelId,
  });

  final List<PlaylistSource> sources;
  final List<Channel> cachedChannels;
  final Set<String> favoriteChannelIds;
  final String? lastChannelId;
}

class SettingsStore {
  static const _sourcesKey = 'sources';
  static const _channelsKey = 'cached_channels';
  static const _favoritesKey = 'favorite_channel_ids';
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

    final channels = channelsJson == null
        ? <Channel>[]
        : (jsonDecode(channelsJson) as List)
            .cast<Map<String, Object?>>()
            .map(Channel.fromJson)
            .toList();

    return SettingsSnapshot(
      sources: sources,
      cachedChannels: channels,
      favoriteChannelIds: prefs.getStringList(_favoritesKey)?.toSet() ?? {},
      lastChannelId: prefs.getString(_lastChannelKey),
    );
  }

  Future<void> saveSources(List<PlaylistSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<void> saveLastChannel(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastChannelKey, channelId);
  }
}
