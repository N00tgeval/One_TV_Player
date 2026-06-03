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
  List<PlaylistSource> sources = [];
  List<Channel> channels = [];
  Set<String> favoriteChannelIds = {};

  List<Channel> get favoriteChannels => channels
      .where((channel) => favoriteChannelIds.contains(channel.id))
      .toList();

  Map<String, List<Channel>> get groupedChannels {
    final grouped = <String, List<Channel>>{};
    for (final channel in channels) {
      grouped.putIfAbsent(channel.group, () => []).add(channel);
    }
    return grouped;
  }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final snapshot = await _settingsStore.load();
    sources = snapshot.sources;
    channels = snapshot.cachedChannels;
    favoriteChannelIds = snapshot.favoriteChannelIds;
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

  Future<void> togglePreset(PlaylistSource preset, bool enabled) async {
    final withoutPreset = sources.where((source) => source.id != preset.id);
    sources = [...withoutPreset, preset.copyWith(enabled: enabled)];
    await _settingsStore.saveSources(sources);
    await refreshChannels();
  }

  Future<void> refreshChannels() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      channels = await _playlistRepository.loadChannels(sources);
      await _settingsStore.saveChannels(channels);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
}
