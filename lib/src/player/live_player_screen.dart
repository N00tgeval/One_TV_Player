import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as exo;

import '../models/channel.dart';

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({
    required this.channel,
    required this.channels,
    this.onHideChannel,
    super.key,
  });

  final Channel channel;
  final List<Channel> channels;
  final ValueChanged<Channel>? onHideChannel;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late final Player player;
  late final VideoController controller;
  late final FocusNode focusNode;
  final subscriptions = <StreamSubscription<Object?>>[];
  Timer? playbackTimeout;
  Timer? firstFrameTimeout;
  late Channel currentChannel;

  var isOpening = true;
  var isBuffering = false;
  var isPlaying = false;
  var hasFirstFrame = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    currentChannel = widget.channel;
    focusNode = FocusNode();
    player = Player();
    controller = VideoController(player, configuration: _videoConfiguration);
    subscriptions.addAll([
      player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() {
          isPlaying = playing;
          if (playing) {
            isOpening = false;
            errorMessage = null;
            _startFirstFrameTimeout();
          }
        });
      }),
      player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        setState(() {
          isBuffering = buffering;
          if (buffering) {
            _startPlaybackTimeout();
          } else {
            isOpening = false;
          }
        });
      }),
      player.stream.error.listen((error) {
        if (!mounted) return;
        setState(() {
          isOpening = false;
          isBuffering = false;
          errorMessage = error;
        });
      }),
    ]);
    _open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    playbackTimeout?.cancel();
    firstFrameTimeout?.cancel();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    focusNode.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      isOpening = true;
      isBuffering = false;
      isPlaying = false;
      hasFirstFrame = false;
      errorMessage = null;
    });
    _startPlaybackTimeout();
    try {
      await player.open(
        Media(currentChannel.url, httpHeaders: _streamHeaders),
        play: true,
      );
      _waitForFirstFrame();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isOpening = false;
        errorMessage = error.toString();
      });
    }
  }

  void _startPlaybackTimeout() {
    playbackTimeout?.cancel();
    playbackTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted || hasFirstFrame || errorMessage != null) return;
      setState(() {
        isOpening = false;
        isBuffering = false;
        errorMessage = 'Stream did not start within 20 seconds.';
      });
    });
  }

  void _startFirstFrameTimeout() {
    if (hasFirstFrame || errorMessage != null) return;
    firstFrameTimeout?.cancel();
    firstFrameTimeout = Timer(const Duration(seconds: 12), () {
      if (!mounted || hasFirstFrame || errorMessage != null) return;
      setState(() {
        isOpening = false;
        isBuffering = false;
        errorMessage = 'Audio started but no video frame was rendered.';
      });
    });
  }

  Future<void> _waitForFirstFrame() async {
    try {
      await controller.waitUntilFirstFrameRendered;
      if (!mounted) return;
      playbackTimeout?.cancel();
      firstFrameTimeout?.cancel();
      setState(() {
        hasFirstFrame = true;
        isOpening = false;
        isBuffering = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted || errorMessage != null) return;
      setState(() {
        isOpening = false;
        isBuffering = false;
        errorMessage = error.toString();
      });
    }
  }

  void _hideChannel() {
    widget.onHideChannel?.call(currentChannel);
    Navigator.of(context).pop();
  }

  void _playRelativeChannel(int direction) {
    final channels = widget.channels;
    if (channels.isEmpty) return;
    final currentIndex = channels.indexWhere(
      (channel) => channel.id == currentChannel.id,
    );
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + direction).clamp(0, channels.length - 1);
    if (nextIndex == currentIndex) return;
    setState(() => currentChannel = channels[nextIndex]);
    _open();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _playRelativeChannel(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _playRelativeChannel(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Video(controller: controller, fit: BoxFit.contain),
            ),
            if (errorMessage != null || isOpening || isBuffering)
              Center(
                child: _PlayerStatusOverlay(
                  isOpening: isOpening,
                  isBuffering: isBuffering,
                  isPlaying: isPlaying,
                  errorMessage: errorMessage,
                  onRetry: _open,
                  onHideChannel:
                      widget.onHideChannel == null ? null : _hideChannel,
                ),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.live_tv),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentChannel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChannelPreviewPlayer extends StatefulWidget {
  const ChannelPreviewPlayer({
    required this.channel,
    required this.session,
    required this.detached,
    required this.onOpenFullscreen,
    super.key,
  });

  final Channel channel;
  final ChannelPlaybackSession session;
  final bool detached;
  final VoidCallback onOpenFullscreen;

  @override
  State<ChannelPreviewPlayer> createState() => _ChannelPreviewPlayerState();
}

class _ChannelPreviewPlayerState extends State<ChannelPreviewPlayer> {
  @override
  void initState() {
    super.initState();
    widget.session.play(widget.channel);
  }

  @override
  void didUpdateWidget(ChannelPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id) {
      widget.session.play(widget.channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff263842)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _ExoPlayerSurface(
          session: widget.session,
          detached: widget.detached,
          compactLabel: widget.channel.name,
          onOpenFullscreen: widget.onOpenFullscreen,
        ),
      ),
    );
  }
}

class ExoLivePlayerScreen extends StatefulWidget {
  const ExoLivePlayerScreen({
    required this.session,
    required this.channels,
    required this.initialChannel,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onHideChannel,
    super.key,
  });

  final ChannelPlaybackSession session;
  final List<Channel> channels;
  final Channel initialChannel;
  final bool Function(Channel channel) isFavorite;
  final ValueChanged<Channel> onToggleFavorite;
  final ValueChanged<Channel>? onHideChannel;

  @override
  State<ExoLivePlayerScreen> createState() => _ExoLivePlayerScreenState();
}

class _ExoLivePlayerScreenState extends State<ExoLivePlayerScreen> {
  late final FocusNode focusNode;
  Timer? controlsTimer;
  late Channel currentChannel;
  var showControls = true;
  var selectedActionIndex = 0;

  @override
  void initState() {
    super.initState();
    currentChannel = widget.initialChannel;
    focusNode = FocusNode();
    widget.session.play(currentChannel);
    _scheduleControlsHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    controlsTimer?.cancel();
    focusNode.dispose();
    super.dispose();
  }

  void _scheduleControlsHide() {
    controlsTimer?.cancel();
    controlsTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || widget.session.errorMessage != null) return;
      setState(() => showControls = false);
      focusNode.requestFocus();
    });
  }

  void _showControls() {
    setState(() => showControls = true);
    _scheduleControlsHide();
  }

  void _toggleControls() {
    if (showControls) {
      controlsTimer?.cancel();
      setState(() => showControls = false);
      focusNode.requestFocus();
    } else {
      _showControls();
    }
  }

  void _playRelativeChannel(int direction) {
    final currentIndex = widget.channels.indexWhere(
      (channel) => channel.id == currentChannel.id,
    );
    if (currentIndex == -1) return;
    final nextIndex =
        (currentIndex + direction).clamp(0, widget.channels.length - 1);
    if (nextIndex == currentIndex) return;
    final nextChannel = widget.channels[nextIndex];
    setState(() {
      currentChannel = nextChannel;
      showControls = true;
    });
    widget.session.play(nextChannel);
    _scheduleControlsHide();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (showControls || widget.session.errorMessage != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _moveSelectedAction(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveSelectedAction(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _playRelativeChannel(
          event.logicalKey == LogicalKeyboardKey.arrowUp ? 1 : -1,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        _runSelectedAction();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
          event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
        _toggleControls();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _playRelativeChannel(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _playRelativeChannel(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.contextMenu ||
        event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
      _toggleControls();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _close() => Navigator.of(context).pop();

  void _hideChannel() {
    widget.onHideChannel?.call(currentChannel);
    Navigator.of(context).pop();
  }

  void _toggleFavorite() {
    widget.onToggleFavorite(currentChannel);
    _showControls();
  }

  void _retry() {
    widget.session.play(currentChannel);
    _showControls();
  }

  List<_OsdActionItem> get _actions {
    return [
      _OsdActionItem(Icons.arrow_back, 'Back', _close),
      _OsdActionItem(
          Icons.skip_previous, 'Prev', () => _playRelativeChannel(-1)),
      _OsdActionItem(Icons.skip_next, 'Next', () => _playRelativeChannel(1)),
      _OsdActionItem(
        widget.isFavorite(currentChannel) ? Icons.star : Icons.star_border,
        widget.isFavorite(currentChannel) ? 'Saved' : 'Favorite',
        _toggleFavorite,
      ),
      if (widget.session.errorMessage != null)
        _OsdActionItem(Icons.refresh, 'Retry', _retry),
      if (widget.onHideChannel != null)
        _OsdActionItem(Icons.visibility_off, 'Hide', _hideChannel),
    ];
  }

  void _moveSelectedAction(int delta) {
    final actions = _actions;
    if (actions.isEmpty) return;
    setState(() {
      selectedActionIndex =
          (selectedActionIndex + delta).clamp(0, actions.length - 1);
    });
    _scheduleControlsHide();
  }

  void _runSelectedAction() {
    final actions = _actions;
    if (actions.isEmpty) return;
    final index = selectedActionIndex.clamp(0, actions.length - 1);
    actions[index].onPressed();
    _scheduleControlsHide();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: _ExoPlayerSurface(
                session: widget.session,
                detached: false,
                compactLabel: currentChannel.name,
                fullscreen: true,
              ),
            ),
            if (showControls || widget.session.errorMessage != null)
              _FullscreenControls(
                channel: currentChannel,
                actions: _actions,
                selectedIndex:
                    selectedActionIndex.clamp(0, _actions.length - 1),
                onSelectIndex: (index) {
                  setState(() => selectedActionIndex = index);
                  _scheduleControlsHide();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenControls extends StatelessWidget {
  const _FullscreenControls({
    required this.channel,
    required this.actions,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  final Channel channel;
  final List<_OsdActionItem> actions;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xff263842)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.live_tv),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xff9aabb2),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              for (var index = 0; index < actions.length; index++)
                _OsdAction(
                  icon: actions[index].icon,
                  label: actions[index].label,
                  selected: index == selectedIndex,
                  onFocus: () => onSelectIndex(index),
                  onPressed: actions[index].onPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OsdActionItem {
  const _OsdActionItem(this.icon, this.label, this.onPressed);

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _OsdAction extends StatelessWidget {
  const _OsdAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onFocus,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onFocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onFocusChange: (focused) {
          if (focused) onFocus();
        },
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xffd7ffe9) : const Color(0xff18262c),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.white : const Color(0xff30424a),
              width: selected ? 3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xff07120d) : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? const Color(0xff07120d) : Colors.white,
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

class _ExoPlayerSurface extends StatelessWidget {
  const _ExoPlayerSurface({
    required this.session,
    required this.detached,
    required this.compactLabel,
    this.onOpenFullscreen,
    this.fullscreen = false,
  });

  final ChannelPlaybackSession session;
  final bool detached;
  final String compactLabel;
  final VoidCallback? onOpenFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final controller = session.controller;
        final showStatus = session.errorMessage != null ||
            session.isOpening ||
            session.isBuffering ||
            !session.hasVideo ||
            controller == null;

        return Stack(
          children: [
            Positioned.fill(
              child: detached || controller == null
                  ? const ColoredBox(color: Colors.black)
                  : exo.VideoPlayer(controller),
            ),
            if (showStatus)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.68),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        detached
                            ? 'Playing fullscreen'
                            : session.errorMessage ??
                                (session.isBuffering
                                    ? 'Buffering'
                                    : 'Opening stream'),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xffc6d2d6),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!fullscreen)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        compactLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onOpenFullscreen,
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('Open'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class ChannelPlaybackSession extends ChangeNotifier {
  exo.VideoPlayerController? controller;
  Channel? channel;
  Timer? playbackTimeout;
  List<String> candidateUrls = const [];
  var candidateIndex = 0;
  var isTryingFallback = false;

  var isOpening = false;
  var isBuffering = false;
  var hasVideo = false;
  String? errorMessage;

  Future<void> play(Channel nextChannel) async {
    final currentController = controller;
    if (channel?.id == nextChannel.id &&
        currentController != null &&
        currentController.value.isInitialized) {
      await currentController.play();
      return;
    }

    playbackTimeout?.cancel();
    currentController?.removeListener(_handleControllerChanged);
    controller = null;
    channel = nextChannel;
    candidateUrls = _candidateUrlsFor(nextChannel);
    candidateIndex = 0;
    isOpening = true;
    isBuffering = false;
    hasVideo = false;
    errorMessage = null;
    notifyListeners();

    await currentController?.dispose();
    await _openCandidate();
  }

  Future<void> _openCandidate() async {
    final nextChannel = channel;
    if (nextChannel == null || candidateUrls.isEmpty) return;
    final streamUrl = candidateUrls[candidateIndex];
    playbackTimeout?.cancel();
    playbackTimeout = Timer(const Duration(seconds: 16), () {
      if (errorMessage != null || hasVideo) return;
      _tryNextFallback('Stream did not start within 16 seconds.');
    });
    try {
      final nextController = exo.VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        formatHint: exo.VideoFormat.hls,
        httpHeaders: _streamHeaders,
        videoPlayerOptions: exo.VideoPlayerOptions(mixWithOthers: true),
        viewType: exo.VideoViewType.platformView,
      );
      controller = nextController;
      nextController.addListener(_handleControllerChanged);
      await nextController.initialize();
      await nextController.play();
      playbackTimeout?.cancel();
      isOpening = false;
      isBuffering = false;
      hasVideo = true;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      playbackTimeout?.cancel();
      await _tryNextFallback(error.toString());
    }
  }

  Future<void> _tryNextFallback(String reason) async {
    if (isTryingFallback) return;
    if (candidateIndex + 1 >= candidateUrls.length) {
      isOpening = false;
      isBuffering = false;
      hasVideo = false;
      errorMessage = reason;
      notifyListeners();
      return;
    }

    isTryingFallback = true;
    final failedController = controller;
    failedController?.removeListener(_handleControllerChanged);
    controller = null;
    candidateIndex += 1;
    isOpening = true;
    isBuffering = false;
    hasVideo = false;
    errorMessage = null;
    notifyListeners();
    await failedController?.dispose();
    isTryingFallback = false;
    await _openCandidate();
  }

  List<String> _candidateUrlsFor(Channel channel) {
    final seen = <String>{};
    return [
      for (final url in [channel.url, ...channel.streamUrls])
        if (url.trim().isNotEmpty && seen.add(url.trim())) url.trim(),
    ];
  }

  Future<void> clear() async {
    playbackTimeout?.cancel();
    final currentController = controller;
    currentController?.removeListener(_handleControllerChanged);
    controller = null;
    channel = null;
    candidateUrls = const [];
    candidateIndex = 0;
    isTryingFallback = false;
    isOpening = false;
    isBuffering = false;
    hasVideo = false;
    errorMessage = null;
    notifyListeners();
    await currentController?.dispose();
  }

  void _handleControllerChanged() {
    final value = controller?.value;
    if (value == null) return;
    final error = value.errorDescription;
    if (error != null) {
      playbackTimeout?.cancel();
      _tryNextFallback(error);
      return;
    }
    isBuffering = value.isBuffering;
    if (value.isPlaying) {
      isOpening = false;
      errorMessage = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    playbackTimeout?.cancel();
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    super.dispose();
  }
}

const _streamHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) OneTVPlayer/0.1',
  'Accept': '*/*',
};

VideoControllerConfiguration get _videoConfiguration {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return const VideoControllerConfiguration(
      vo: 'mediacodec_embed',
      hwdec: 'mediacodec',
      androidAttachSurfaceAfterVideoParameters: true,
    );
  }
  return const VideoControllerConfiguration();
}

class _PlayerStatusOverlay extends StatelessWidget {
  const _PlayerStatusOverlay({
    required this.isOpening,
    required this.isBuffering,
    required this.isPlaying,
    required this.errorMessage,
    required this.onRetry,
    required this.onHideChannel,
  });

  final bool isOpening;
  final bool isBuffering;
  final bool isPlaying;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback? onHideChannel;

  @override
  Widget build(BuildContext context) {
    final error = errorMessage;
    final friendlyError = error == null ? null : _friendlyError(error);
    final title = error != null
        ? 'Stream failed'
        : isBuffering
            ? 'Buffering'
            : isOpening
                ? 'Opening stream'
                : isPlaying
                    ? 'Playing'
                    : 'Waiting for stream';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff263842)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error == null) ...[
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Icon(Icons.warning_amber,
                    color: Color(0xfff2cf66), size: 38),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  friendlyError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xffb4c0c5),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Details: $error',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff72838b),
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                if (onHideChannel != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onHideChannel,
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Hide channel'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('20 seconds')) {
      return 'This channel did not start. The stream may be offline or blocked.';
    }
    if (lower.contains('no video frame')) {
      return 'The stream produced audio but Android did not render video. This may be an emulator/player compatibility issue.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'The stream server did not respond. This channel is probably offline right now.';
    }
    if (lower.contains('ffurl_read') ||
        lower.contains('tcp:') ||
        lower.contains('connection') ||
        lower.contains('network')) {
      return 'The app could not read data from the stream server.';
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'The stream server refused access. It may be region-blocked or require special headers.';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'The stream URL no longer exists.';
    }
    if (lower.contains('unsupported') || lower.contains('codec')) {
      return 'This stream format is not supported on this device.';
    }
    return 'This public stream could not be played. Try another channel or hide it from the list.';
  }
}
