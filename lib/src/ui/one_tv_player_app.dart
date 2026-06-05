import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/playlist_source.dart';
import '../services/playlist_repository.dart';
import '../storage/settings_store.dart';
import 'home_screen.dart';

class OneTvPlayerApp extends StatefulWidget {
  const OneTvPlayerApp({super.key});

  @override
  State<OneTvPlayerApp> createState() => _OneTvPlayerAppState();
}

class _OneTvPlayerAppState extends State<OneTvPlayerApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(
      settingsStore: SettingsStore(),
      playlistRepository: PlaylistRepository(),
    )..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One TV Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1f7a5a),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      ),
      home: HomeScreen(controller: controller),
    );
  }
}

class AppController extends ChangeNotifier {
  AppController({
    required SettingsStore settingsStore,
    required PlaylistRepository playlistRepository,
  })  : _settingsStore = settingsStore,
        _playlistRepository = playlistRepository;

  final SettingsStore _settingsStore;
  final PlaylistRepository _playlistRepository;

  var isLoading = true;
  String? errorMessage;
  Map<String, String> sourceErrorMessages = {};
  Map<String, SourceTestResult> sourceTestResults = {};
  List<PlaylistSource> sources = [];
  List<Channel> channels = [];
  Set<String> favoriteChannelIds = {};
  Set<String> hiddenChannelIds = {};

  List<Channel> get visibleChannels => channels
      .where((channel) => !hiddenChannelIds.contains(channel.id))
      .toList();

  List<Channel> get favoriteChannels => visibleChannels
      .where((channel) => favoriteChannelIds.contains(channel.id))
      .toList();

  Map<String, List<Channel>> get groupedChannels {
    final grouped = <String, List<Channel>>{};
    for (final channel in visibleChannels) {
      grouped.putIfAbsent(channel.group, () => []).add(channel);
    }
    return grouped;
  }

  int channelCountForSource(PlaylistSource source) {
    return channels.where((channel) => channel.sourceId == source.id).length;
  }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final snapshot = await _settingsStore.load();
    var loadedSources = snapshot.sources;
    final hasLegacyDemo = loadedSources.any(
      (source) => source.id == 'free-tv' && source.enabled,
    );
    final hasSamsungDemo = loadedSources.any(
      (source) => source.id == 'samsung-tv-plus',
    );
    var shouldRefreshAfterLoad = false;
    if (hasLegacyDemo && !hasSamsungDemo) {
      final samsungDemo = fastPresets.firstWhere(
        (preset) => preset.id == 'samsung-tv-plus',
      );
      loadedSources = [
        for (final source in loadedSources)
          if (source.id == 'free-tv')
            samsungDemo.copyWith(enabled: true)
          else
            source,
      ];
      await _settingsStore.saveSources(loadedSources);
      shouldRefreshAfterLoad = true;
    }
    sources = loadedSources;
    channels = _playlistRepository.deduplicateChannels(snapshot.cachedChannels);
    favoriteChannelIds = snapshot.favoriteChannelIds;
    hiddenChannelIds = snapshot.hiddenChannelIds;
    if (shouldRefreshAfterLoad) {
      try {
        await refreshChannels();
      } catch (error) {
        errorMessage = error.toString();
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> addM3uSource(String name, String url) async {
    final source = PlaylistSource(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'M3U playlist' : name.trim(),
      url: url.trim(),
      type: PlaylistSourceType.m3uUrl,
    );
    sources = [...sources, source];
    await _settingsStore.saveSources(sources);
    await refreshChannels();
  }

  Future<bool> addXtreamSource({
    required String name,
    required List<String> serverUrls,
    required String username,
    required String password,
  }) async {
    final cleanServerUrls = serverUrls
        .map((url) => url.trim())
        .where((url) => url.startsWith('http://') || url.startsWith('https://'))
        .toSet()
        .toList();
    if (cleanServerUrls.isEmpty ||
        username.trim().isEmpty ||
        password.trim().isEmpty) {
      errorMessage = 'Enter at least one server URL, username, and password.';
      notifyListeners();
      return false;
    }
    final source = PlaylistSource(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Xtream source' : name.trim(),
      url: cleanServerUrls.first,
      type: PlaylistSourceType.xtream,
      serverUrls: cleanServerUrls,
      username: username.trim(),
      password: password.trim(),
    );
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final loadedChannels = await _playlistRepository.loadChannels([source]);
      sources = [...sources, source];
      channels = _playlistRepository.deduplicateChannels([
        ...channels,
        ...loadedChannels,
      ]);
      await _settingsStore.saveSources(sources);
      await _settingsStore.saveChannels(channels);
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return true;
  }

  Future<void> togglePreset(PlaylistSource preset, bool enabled) async {
    final withoutPreset = sources.where((source) => source.id != preset.id);
    sources = [...withoutPreset, preset.copyWith(enabled: enabled)];
    await _settingsStore.saveSources(sources);
    await refreshChannels();
  }

  Future<void> enableDemoFastPreset() async {
    final demoPreset = fastPresets.firstWhere(
      (preset) => preset.id == 'samsung-tv-plus',
      orElse: () => fastPresets.first,
    );
    final userSources = sources.where(
      (source) => source.type != PlaylistSourceType.fastPreset,
    );
    sources = [...userSources, demoPreset.copyWith(enabled: true)];
    await _settingsStore.saveSources(sources);
    await refreshChannels();
  }

  Future<void> refreshChannels() async {
    isLoading = true;
    errorMessage = null;
    sourceErrorMessages = {};
    notifyListeners();
    try {
      final loadedChannels = <Channel>[];
      final errors = <String, String>{};
      for (final source in sources.where((source) => source.enabled)) {
        try {
          loadedChannels.addAll(
            await _playlistRepository.loadChannels([source]),
          );
        } catch (error) {
          errors[source.id] = error.toString();
        }
      }
      channels = _playlistRepository.deduplicateChannels(loadedChannels);
      sourceErrorMessages = errors;
      await _settingsStore.saveChannels(channels);
      if (errors.isNotEmpty && loadedChannels.isEmpty) {
        errorMessage = 'No sources could be loaded.';
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSource(PlaylistSource source) async {
    isLoading = true;
    errorMessage = null;
    sourceErrorMessages = {...sourceErrorMessages}..remove(source.id);
    notifyListeners();
    try {
      final otherChannels =
          channels.where((channel) => channel.sourceId != source.id).toList();
      final refreshedChannels = source.enabled
          ? await _playlistRepository.loadChannels([source])
          : <Channel>[];
      channels = _playlistRepository.deduplicateChannels([
        ...otherChannels,
        ...refreshedChannels,
      ]);
      await _settingsStore.saveChannels(channels);
    } catch (error) {
      sourceErrorMessages = {
        ...sourceErrorMessages,
        source.id: error.toString(),
      };
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> testSource(PlaylistSource source) async {
    isLoading = true;
    errorMessage = null;
    sourceTestResults = {...sourceTestResults}..remove(source.id);
    notifyListeners();
    try {
      final result = await _playlistRepository.testSource(source);
      sourceTestResults = {
        ...sourceTestResults,
        source.id: result,
      };
      if (!result.success) {
        sourceErrorMessages = {
          ...sourceErrorMessages,
          source.id: result.message,
        };
      } else {
        sourceErrorMessages = {...sourceErrorMessages}..remove(source.id);
      }
    } catch (error) {
      final result = SourceTestResult(
        message: error.toString(),
        success: false,
      );
      sourceTestResults = {
        ...sourceTestResults,
        source.id: result,
      };
      sourceErrorMessages = {
        ...sourceErrorMessages,
        source.id: result.message,
      };
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSourceEnabled(PlaylistSource source, bool enabled) async {
    sources = [
      for (final current in sources)
        if (current.id == source.id)
          current.copyWith(enabled: enabled)
        else
          current,
    ];
    await _settingsStore.saveSources(sources);
    final updatedSource = sources.firstWhere(
      (current) => current.id == source.id,
    );
    await refreshSource(updatedSource);
  }

  Future<void> deleteSource(PlaylistSource source) async {
    sources = sources.where((current) => current.id != source.id).toList();
    sourceErrorMessages = {...sourceErrorMessages}..remove(source.id);
    sourceTestResults = {...sourceTestResults}..remove(source.id);
    channels =
        channels.where((channel) => channel.sourceId != source.id).toList();
    favoriteChannelIds = {
      for (final channelId in favoriteChannelIds)
        if (channels.any((channel) => channel.id == channelId)) channelId,
    };
    hiddenChannelIds = {
      for (final channelId in hiddenChannelIds)
        if (channels.any((channel) => channel.id == channelId)) channelId,
    };
    await _settingsStore.saveSources(sources);
    await _settingsStore.saveChannels(channels);
    await _settingsStore.saveFavorites(favoriteChannelIds);
    await _settingsStore.saveHiddenChannels(hiddenChannelIds);
    notifyListeners();
  }

  Future<void> toggleFavorite(Channel channel) async {
    final next = {...favoriteChannelIds};
    if (!next.add(channel.id)) {
      next.remove(channel.id);
    }
    favoriteChannelIds = next;
    await _settingsStore.saveFavorites(favoriteChannelIds);
    notifyListeners();
  }

  Future<void> hideUnavailableChannel(Channel channel) async {
    hiddenChannelIds = {...hiddenChannelIds, channel.id};
    favoriteChannelIds = {...favoriteChannelIds}..remove(channel.id);
    await _settingsStore.saveHiddenChannels(hiddenChannelIds);
    await _settingsStore.saveFavorites(favoriteChannelIds);
    notifyListeners();
  }
}
