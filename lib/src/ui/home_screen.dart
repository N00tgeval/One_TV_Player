import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../player/live_player_screen.dart';
import 'one_tv_player_app.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var selectedGroup = 'All';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final channelGroups = controller.groupedChannels.keys.toList()..sort();
        final groups = ['All', 'Favorites', ...channelGroups];
        final channels = _visibleChannels(controller);

        return Scaffold(
          appBar: AppBar(
            title: const Text('One TV Player'),
            actions: [
              IconButton(
                tooltip: 'Refresh sources',
                onPressed: controller.sources.isEmpty ? null : controller.refreshChannels,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Sources',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(controller: controller),
                  ),
                ),
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: groups.indexOf(selectedGroup).clamp(0, groups.length - 1),
                onDestinationSelected: (index) => setState(() => selectedGroup = groups[index]),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final group in groups)
                    NavigationRailDestination(
                      icon: const Icon(Icons.live_tv),
                      label: Text(group, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _ChannelPane(
                  isLoading: controller.isLoading,
                  errorMessage: controller.errorMessage,
                  channels: channels,
                  hasSources: controller.sources.isNotEmpty,
                  isFavorite: (channel) => controller.favoriteChannelIds.contains(channel.id),
                  onFavorite: controller.toggleFavorite,
                  onOpenSettings: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(controller: controller),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Channel> _visibleChannels(AppController controller) {
    if (selectedGroup == 'Favorites') return controller.favoriteChannels;
    if (selectedGroup == 'All') return controller.channels;
    return controller.groupedChannels[selectedGroup] ?? [];
  }
}

class _ChannelPane extends StatelessWidget {
  const _ChannelPane({
    required this.isLoading,
    required this.errorMessage,
    required this.channels,
    required this.hasSources,
    required this.isFavorite,
    required this.onFavorite,
    required this.onOpenSettings,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<Channel> channels;
  final bool hasSources;
  final bool Function(Channel channel) isFavorite;
  final ValueChanged<Channel> onFavorite;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (isLoading && channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasSources) {
      return Center(
        child: FilledButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.add_link),
          label: const Text('Add a source'),
        ),
      );
    }

    if (errorMessage != null && channels.isEmpty) {
      return Center(child: Text(errorMessage!));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 108,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            autofocus: index == 0,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LivePlayerScreen(channel: channel),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(
                          channel.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favorite',
                    onPressed: () => onFavorite(channel),
                    icon: Icon(isFavorite(channel) ? Icons.star : Icons.star_border),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
