import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import '../player/live_player_screen.dart';
import 'one_tv_player_app.dart';
import 'settings_screen.dart';

KeyEventResult _trapFocusEdges(
  KeyEvent event, {
  bool up = false,
  bool down = false,
  bool left = false,
  bool right = false,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (up && event.logicalKey == LogicalKeyboardKey.arrowUp) {
    return KeyEventResult.handled;
  }
  if (down && event.logicalKey == LogicalKeyboardKey.arrowDown) {
    return KeyEventResult.handled;
  }
  if (left && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    return KeyEventResult.handled;
  }
  if (right && event.logicalKey == LogicalKeyboardKey.arrowRight) {
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _allGroup = 'All';
  static const _favoritesGroup = 'Favorites';

  final searchController = TextEditingController();
  final firstChannelFocusNode = FocusNode();
  final playbackSession = ChannelPlaybackSession();

  var selectedGroup = _allGroup;
  var searchQuery = '';
  Channel? previewChannel;
  var isFullscreenOpen = false;

  @override
  void dispose() {
    searchController.dispose();
    firstChannelFocusNode.dispose();
    playbackSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final groups = _groups(controller);
        if (!groups.contains(selectedGroup)) selectedGroup = _allGroup;
        final channels = _visibleChannels(controller);
        final isSearching = searchQuery.trim().isNotEmpty;
        final activePreviewChannel = _activePreviewChannel(channels);

        return Scaffold(
          backgroundColor: const Color(0xff080d10),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 720;
                final channelPane = _ChannelPane(
                  title: isSearching ? 'Search results' : selectedGroup,
                  searchController: searchController,
                  searchQuery: searchQuery,
                  isLoading: controller.isLoading,
                  errorMessage: controller.errorMessage,
                  channels: channels,
                  totalChannelCount: controller.visibleChannels.length,
                  hiddenChannelCount: controller.hiddenChannelIds.length,
                  hasSources: controller.sources.isNotEmpty,
                  previewChannel: activePreviewChannel,
                  playbackSession: playbackSession,
                  previewDetached: isFullscreenOpen,
                  isFavorite: (channel) =>
                      controller.favoriteChannelIds.contains(channel.id),
                  firstChannelFocusNode: firstChannelFocusNode,
                  onEnableDemoPreset: controller.enableDemoFastPreset,
                  onFavorite: controller.toggleFavorite,
                  onOpenSettings: () => _openSettings(context),
                  onSearchChanged: (query) =>
                      setState(() => searchQuery = query),
                  onSearchCleared: () {
                    searchController.clear();
                    setState(() => searchQuery = '');
                  },
                  onMoveToResults: () {
                    if (channels.isNotEmpty) {
                      firstChannelFocusNode.requestFocus();
                    }
                  },
                  onPreview: _previewOrOpenFullscreen,
                  onOpenFullscreen: (channel) =>
                      _openFullscreen(context, channel, channels),
                  showRemoteHint: !isCompact,
                );

                if (isCompact) {
                  return _CompactBrowseLayout(
                    groups: groups,
                    selectedGroup: selectedGroup,
                    channelCountForGroup: (group) =>
                        _channelCountForGroup(controller, group),
                    isLoading: controller.isLoading,
                    hasSources: controller.sources.isNotEmpty,
                    onRefresh: controller.sources.isEmpty
                        ? null
                        : controller.refreshChannels,
                    onOpenSettings: () => _openSettings(context),
                    onSelectGroup: _selectGroup,
                    child: channelPane,
                  );
                }

                return FocusTraversalGroup(
                  child: Row(
                    children: [
                      _DestinationSidebar(
                        hasSources: controller.sources.isNotEmpty,
                        isLoading: controller.isLoading,
                        onRefresh: controller.sources.isEmpty
                            ? null
                            : controller.refreshChannels,
                        onOpenSettings: () => _openSettings(context),
                      ),
                      _CategoryPane(
                        groups: groups,
                        selectedGroup: selectedGroup,
                        channelCountForGroup: (group) =>
                            _channelCountForGroup(controller, group),
                        onSelectGroup: _selectGroup,
                      ),
                      Expanded(child: channelPane),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<String> _groups(AppController controller) {
    final channelGroups = controller.groupedChannels.keys.toList()..sort();
    return [
      _allGroup,
      if (controller.favoriteChannels.isNotEmpty) _favoritesGroup,
      ...channelGroups,
    ];
  }

  int _channelCountForGroup(AppController controller, String group) {
    if (group == _favoritesGroup) return controller.favoriteChannels.length;
    if (group == _allGroup) return controller.channels.length;
    return controller.groupedChannels[group]?.length ?? 0;
  }

  List<Channel> _visibleChannels(AppController controller) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      return controller.visibleChannels.where((channel) {
        final searchableText = [
          channel.name,
          channel.group,
          channel.tvgName,
        ].whereType<String>().join(' ').toLowerCase();
        return searchableText.contains(query);
      }).toList();
    }
    if (selectedGroup == _favoritesGroup) return controller.favoriteChannels;
    if (selectedGroup == _allGroup) return controller.visibleChannels;
    return controller.groupedChannels[selectedGroup] ?? [];
  }

  Channel? _activePreviewChannel(List<Channel> channels) {
    final current = previewChannel;
    if (current == null) return null;
    for (final channel in channels) {
      if (channel.id == current.id) return channel;
    }
    previewChannel = null;
    playbackSession.clear();
    return null;
  }

  void _previewOrOpenFullscreen(Channel channel) {
    final current = previewChannel;
    if (current != null && current.id == channel.id) {
      _openFullscreen(context, channel, _visibleChannels(widget.controller));
      return;
    }
    setState(() => previewChannel = channel);
    playbackSession.play(channel);
  }

  void _selectGroup(String group) {
    searchController.clear();
    playbackSession.clear();
    setState(() {
      selectedGroup = group;
      searchQuery = '';
      previewChannel = null;
    });
  }

  Future<void> _openFullscreen(
    BuildContext context,
    Channel channel,
    List<Channel> channels,
  ) async {
    final navigator = Navigator.of(context);
    setState(() => isFullscreenOpen = true);
    await playbackSession.play(channel);
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ExoLivePlayerScreen(
          session: playbackSession,
          initialChannel: channel,
          channels: channels,
          isFavorite: (channel) =>
              widget.controller.favoriteChannelIds.contains(channel.id),
          onToggleFavorite: widget.controller.toggleFavorite,
          onHideChannel: widget.controller.hideUnavailableChannel,
        ),
      ),
    );
    if (mounted) setState(() => isFullscreenOpen = false);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(controller: widget.controller),
      ),
    );
  }
}

class _CompactBrowseLayout extends StatelessWidget {
  const _CompactBrowseLayout({
    required this.groups,
    required this.selectedGroup,
    required this.channelCountForGroup,
    required this.isLoading,
    required this.hasSources,
    required this.onRefresh,
    required this.onOpenSettings,
    required this.onSelectGroup,
    required this.child,
  });

  final List<String> groups;
  final String selectedGroup;
  final int Function(String group) channelCountForGroup;
  final bool isLoading;
  final bool hasSources;
  final VoidCallback? onRefresh;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onSelectGroup;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: Color(0xff0d1418),
            border: Border(bottom: BorderSide(color: Color(0xff223038))),
          ),
          child: Row(
            children: [
              const _CompactAppMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'One TV Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh sources',
                onPressed: isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: hasSources ? 'Sources' : 'Add a source',
                onPressed: onOpenSettings,
                icon: Icon(hasSources ? Icons.hub : Icons.add_link),
              ),
            ],
          ),
        ),
        _CategoryStrip(
          groups: groups,
          selectedGroup: selectedGroup,
          channelCountForGroup: channelCountForGroup,
          onSelectGroup: onSelectGroup,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _CompactAppMark extends StatelessWidget {
  const _CompactAppMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff12221d),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff2ba779), width: 1.2),
      ),
      child: const SizedBox(
        width: 38,
        height: 38,
        child: Center(
          child: Text(
            '1',
            style: TextStyle(
              color: Color(0xffbfffe2),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.groups,
    required this.selectedGroup,
    required this.channelCountForGroup,
    required this.onSelectGroup,
  });

  final List<String> groups;
  final String selectedGroup;
  final int Function(String group) channelCountForGroup;
  final ValueChanged<String> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _CategoryChip(
            label: group,
            count: channelCountForGroup(group),
            selected: group == selectedGroup,
            trapLeft: index == 0,
            trapRight: index == groups.length - 1,
            onPressed: () => onSelectGroup(group),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.trapLeft,
    required this.trapRight,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final bool trapLeft;
  final bool trapRight;
  final VoidCallback onPressed;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final background = hasFocus
        ? const Color(0xffd7ffe9)
        : widget.selected
            ? const Color(0xff18382d)
            : const Color(0xff101a20);
    final foreground = hasFocus ? const Color(0xff07120d) : Colors.white;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _trapFocusEdges(
        event,
        left: widget.trapLeft,
        right: widget.trapRight,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onFocusChange: (focused) => setState(() => hasFocus = focused),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minWidth: 86, maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: hasFocus
                  ? Colors.white
                  : widget.selected
                      ? const Color(0xff50c58f)
                      : const Color(0xff263842),
              width: hasFocus ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.label == 'Favorites' ? Icons.star : Icons.folder,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.count.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.74),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationSidebar extends StatelessWidget {
  const _DestinationSidebar({
    required this.hasSources,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final bool hasSources;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      color: const Color(0xff0d1418),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _SidebarMetrics.fromHeight(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: metrics.padding,
            ),
            child: Column(
              children: [
                _AppMark(size: metrics.logoSize),
                SizedBox(height: metrics.logoGap),
                _SidebarAction(
                  autofocus: true,
                  icon: Icons.live_tv,
                  tooltip: 'Live TV',
                  selected: true,
                  size: metrics.itemSize,
                  trapUp: true,
                  onPressed: () {},
                ),
                SizedBox(height: metrics.gap),
                _SidebarAction(
                  icon: Icons.tv,
                  tooltip: 'Series',
                  selected: false,
                  size: metrics.itemSize,
                  onPressed: null,
                ),
                SizedBox(height: metrics.gap),
                _SidebarAction(
                  icon: Icons.movie,
                  tooltip: 'Movies',
                  selected: false,
                  size: metrics.itemSize,
                  onPressed: null,
                ),
                SizedBox(height: metrics.gap),
                _SidebarAction(
                  icon: Icons.video_library,
                  tooltip: 'VOD',
                  selected: false,
                  size: metrics.itemSize,
                  onPressed: null,
                ),
                SizedBox(height: metrics.gap),
                _SidebarAction(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  selected: false,
                  size: metrics.itemSize,
                  onPressed: isLoading ? null : onRefresh,
                ),
                const Spacer(),
                _SidebarAction(
                  icon: Icons.hub,
                  tooltip: 'Sources',
                  selected: false,
                  size: metrics.itemSize,
                  trapDown: true,
                  onPressed: onOpenSettings,
                ),
                SizedBox(height: metrics.gap),
                _SidebarAction(
                  icon: Icons.settings,
                  tooltip: 'Settings',
                  selected: false,
                  size: metrics.itemSize,
                  trapDown: true,
                  onPressed: null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SidebarMetrics {
  const _SidebarMetrics({
    required this.padding,
    required this.logoSize,
    required this.logoGap,
    required this.itemSize,
    required this.gap,
  });

  final double padding;
  final double logoSize;
  final double logoGap;
  final double itemSize;
  final double gap;

  factory _SidebarMetrics.fromHeight(double height) {
    const itemCount = 7;
    const ideal = _SidebarMetrics(
      padding: 12,
      logoSize: 50,
      logoGap: 16,
      itemSize: 52,
      gap: 8,
    );
    final idealHeight = (ideal.padding * 2) +
        ideal.logoSize +
        ideal.logoGap +
        (ideal.itemSize * itemCount) +
        (ideal.gap * (itemCount - 1));
    final scale = (height / idealHeight).clamp(0.76, 1.0);
    return _SidebarMetrics(
      padding: (ideal.padding * scale).clamp(6, ideal.padding),
      logoSize: (ideal.logoSize * scale).clamp(38, ideal.logoSize),
      logoGap: (ideal.logoGap * scale).clamp(8, ideal.logoGap),
      itemSize: (ideal.itemSize * scale).clamp(40, ideal.itemSize),
      gap: (ideal.gap * scale).clamp(4, ideal.gap),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff12221d),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff2ba779), width: 1.4),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '1',
            style: TextStyle(
              color: const Color(0xffbfffe2),
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarAction extends StatefulWidget {
  const _SidebarAction({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    this.size = 52,
    this.autofocus = false,
    this.trapUp = false,
    this.trapDown = false,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;
  final double size;
  final bool autofocus;
  final bool trapUp;
  final bool trapDown;

  @override
  State<_SidebarAction> createState() => _SidebarActionState();
}

class _SidebarActionState extends State<_SidebarAction> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final borderColor = hasFocus
        ? const Color(0xffffffff)
        : widget.selected
            ? const Color(0xff5fd39b)
            : Colors.transparent;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _trapFocusEdges(
        event,
        up: widget.trapUp,
        down: widget.trapDown,
      ),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(8),
          onFocusChange: (focused) => setState(() => hasFocus = focused),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.selected
                  ? const Color(0xff163027)
                  : const Color(0xff101a20),
              border: Border.all(color: borderColor, width: hasFocus ? 3 : 1.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: hasFocus
                  ? const [
                      BoxShadow(
                        color: Color(0x665fd39b),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: enabled ? Colors.white : const Color(0xff607078),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPane extends StatelessWidget {
  const _CategoryPane({
    required this.groups,
    required this.selectedGroup,
    required this.channelCountForGroup,
    required this.onSelectGroup,
  });

  final List<String> groups;
  final String selectedGroup;
  final int Function(String group) channelCountForGroup;
  final ValueChanged<String> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      decoration: const BoxDecoration(
        color: Color(0xff0f171c),
        border: Border(
          right: BorderSide(color: Color(0xff223038)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One TV Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live categories',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff96a6ad),
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _CategoryTile(
                  label: group,
                  count: channelCountForGroup(group),
                  selected: group == selectedGroup,
                  trapUp: index == 0,
                  trapDown: index == groups.length - 1,
                  onPressed: () => onSelectGroup(group),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.trapUp,
    required this.trapDown,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final bool trapUp;
  final bool trapDown;
  final VoidCallback onPressed;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final background = hasFocus
        ? const Color(0xffd7ffe9)
        : widget.selected
            ? const Color(0xff18382d)
            : Colors.transparent;
    final foreground = hasFocus ? const Color(0xff07120d) : Colors.white;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _trapFocusEdges(
        event,
        up: widget.trapUp,
        down: widget.trapDown,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onFocusChange: (focused) => setState(() => hasFocus = focused),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                color: hasFocus
                    ? Colors.white
                    : widget.selected
                        ? const Color(0xff50c58f)
                        : Colors.transparent,
                width: hasFocus ? 3 : 1.4,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.label == 'Favorites' ? Icons.star : Icons.folder,
                  size: 22,
                  color: foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.count.toString(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground.withValues(alpha: 0.74),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelPane extends StatelessWidget {
  const _ChannelPane({
    required this.title,
    required this.searchController,
    required this.searchQuery,
    required this.isLoading,
    required this.errorMessage,
    required this.channels,
    required this.totalChannelCount,
    required this.hiddenChannelCount,
    required this.hasSources,
    required this.previewChannel,
    required this.playbackSession,
    required this.previewDetached,
    required this.isFavorite,
    required this.firstChannelFocusNode,
    required this.onEnableDemoPreset,
    required this.onFavorite,
    required this.onOpenSettings,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onMoveToResults,
    required this.onPreview,
    required this.onOpenFullscreen,
    required this.showRemoteHint,
  });

  final String title;
  final TextEditingController searchController;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final List<Channel> channels;
  final int totalChannelCount;
  final int hiddenChannelCount;
  final bool hasSources;
  final Channel? previewChannel;
  final ChannelPlaybackSession playbackSession;
  final bool previewDetached;
  final bool Function(Channel channel) isFavorite;
  final FocusNode firstChannelFocusNode;
  final VoidCallback onEnableDemoPreset;
  final ValueChanged<Channel> onFavorite;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onMoveToResults;
  final ValueChanged<Channel> onPreview;
  final ValueChanged<Channel> onOpenFullscreen;
  final bool showRemoteHint;

  @override
  Widget build(BuildContext context) {
    if (isLoading && channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasSources) {
      return _EmptyState(
        icon: Icons.add_link,
        title: 'Add a source',
        subtitle: 'Connect an M3U playlist or enable a public FAST preset.',
        actionLabel: 'Sources',
        onPressed: onOpenSettings,
        secondaryActionLabel: 'Enable demo FAST',
        onSecondaryPressed: onEnableDemoPreset,
      );
    }

    if (errorMessage != null && channels.isEmpty) {
      return _EmptyState(
        icon: Icons.warning_amber,
        title: 'Could not load channels',
        subtitle: errorMessage!,
        actionLabel: 'Sources',
        onPressed: onOpenSettings,
      );
    }

    if (channels.isEmpty && searchQuery.trim().isEmpty) {
      return _EmptyState(
        icon: Icons.tv_off,
        title: 'No channels here',
        subtitle: totalChannelCount == 0
            ? 'Refresh sources or add another playlist.'
            : 'Choose another category.',
        actionLabel: 'Sources',
        onPressed: onOpenSettings,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitleText,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xff9aabb2),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (showRemoteHint) ...[
                    const Icon(Icons.keyboard_arrow_up,
                        color: Color(0xff6f858d)),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Color(0xff6f858d)),
                    const SizedBox(width: 12),
                    Text(
                      'OK to play',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xff9aabb2),
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _SearchBox(
                controller: searchController,
                query: searchQuery,
                onChanged: onSearchChanged,
                onClear: onSearchCleared,
                onMoveToResults: onMoveToResults,
              ),
              if (previewChannel != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 214,
                  child: ChannelPreviewPlayer(
                    channel: previewChannel!,
                    session: playbackSession,
                    detached: previewDetached,
                    onOpenFullscreen: () => onOpenFullscreen(previewChannel!),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (channels.isEmpty)
          Expanded(
            child: _EmptyState(
              icon: Icons.search_off,
              title: 'No matches',
              subtitle: 'Try another channel name or category.',
              actionLabel: 'Clear search',
              onPressed: onSearchCleared,
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const maxCrossAxisExtent = 430.0;
                const crossAxisSpacing = 12.0;
                const horizontalPadding = 52.0;
                final crossAxisExtent =
                    (constraints.maxWidth - horizontalPadding).clamp(
                  maxCrossAxisExtent,
                  double.infinity,
                );
                final columnCount =
                    (crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
                        .ceil()
                        .clamp(1, channels.length);

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 28, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxCrossAxisExtent,
                    mainAxisExtent: 92,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return Focus(
                      onKeyEvent: (_, event) => _trapFocusEdges(
                        event,
                        up: index < columnCount,
                        down: index + columnCount >= channels.length,
                      ),
                      child: _ChannelTile(
                        channel: channel,
                        focusNode: index == 0 ? firstChannelFocusNode : null,
                        autofocus: index == 0,
                        isPreviewing: previewChannel?.id == channel.id,
                        isFavorite: isFavorite(channel),
                        onFavorite: () => onFavorite(channel),
                        onPlay: () => onPreview(channel),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  String get _subtitleText {
    final base = searchQuery.trim().isEmpty
        ? '${channels.length} channels'
        : '${channels.length} matches';
    if (hiddenChannelCount == 0) return base;
    return '$base - $hiddenChannelCount hidden';
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.onMoveToResults,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onMoveToResults;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final FocusNode focusNode;

  var hasFocus = false;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onMoveToResults();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    )..addListener(() => setState(() => hasFocus = focusNode.hasFocus));
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        color: hasFocus ? const Color(0xffeefcf4) : const Color(0xff101a20),
        border: Border.all(
          color: hasFocus ? Colors.white : const Color(0xff263842),
          width: hasFocus ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        focusNode: focusNode,
        controller: widget.controller,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onMoveToResults,
        onSubmitted: (_) => widget.onMoveToResults(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: hasFocus ? const Color(0xff06110c) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
        decoration: InputDecoration(
          hintText: 'Search channels',
          hintStyle: TextStyle(
            color: hasFocus ? const Color(0xff315443) : const Color(0xff8a9aa2),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: hasFocus ? const Color(0xff163a2c) : const Color(0xff7ee0b2),
          ),
          suffixIcon: widget.query.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: widget.onClear,
                  icon: const Icon(Icons.close),
                  color: hasFocus
                      ? const Color(0xff163a2c)
                      : const Color(0xffc6d2d6),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  const _ChannelTile({
    required this.channel,
    required this.autofocus,
    required this.isPreviewing,
    required this.isFavorite,
    required this.onFavorite,
    required this.onPlay,
    this.focusNode,
  });

  final Channel channel;
  final bool autofocus;
  final bool isPreviewing;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onPlay;
  final FocusNode? focusNode;

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      borderRadius: BorderRadius.circular(8),
      onFocusChange: (focused) => setState(() => hasFocus = focused),
      onTap: widget.onPlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasFocus
              ? const Color(0xffeefcf4)
              : widget.isPreviewing
                  ? const Color(0xff163027)
                  : const Color(0xff121d23),
          border: Border.all(
            color: hasFocus
                ? Colors.white
                : widget.isPreviewing
                    ? const Color(0xff5fd39b)
                    : const Color(0xff263842),
            width: hasFocus || widget.isPreviewing ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: hasFocus
              ? const [
                  BoxShadow(
                    color: Color(0x735fd39b),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _ChannelLogo(channel: widget.channel, focused: hasFocus),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              hasFocus ? const Color(0xff06110c) : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.channel.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasFocus
                              ? const Color(0xff254737)
                              : const Color(0xff9aabb2),
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: widget.isFavorite ? 'Remove favorite' : 'Favorite',
              onPressed: widget.onFavorite,
              icon: Icon(widget.isFavorite ? Icons.star : Icons.star_border),
              color:
                  hasFocus ? const Color(0xff0b2a1f) : const Color(0xfff2cf66),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel, required this.focused});

  final Channel channel;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final logoUrl = channel.logoUrl;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: focused ? const Color(0xffd6eee2) : const Color(0xff0a1115),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? const Color(0xff85bc9d) : const Color(0xff263842),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl == null || logoUrl.isEmpty
          ? Icon(
              Icons.live_tv,
              color:
                  focused ? const Color(0xff183a2c) : const Color(0xff7ee0b2),
            )
          : Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.live_tv,
                color:
                    focused ? const Color(0xff183a2c) : const Color(0xff7ee0b2),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
    this.secondaryActionLabel,
    this.onSecondaryPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xff7ee0b2)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff9aabb2),
                  ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.settings),
              label: Text(actionLabel),
            ),
            if (secondaryActionLabel != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onSecondaryPressed,
                icon: const Icon(Icons.playlist_add_check),
                label: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
