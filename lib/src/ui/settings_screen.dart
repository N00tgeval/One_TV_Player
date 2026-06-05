import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/playlist_source.dart';
import '../services/playlist_repository.dart';
import 'one_tv_player_app.dart';

enum _SourceFormMode { none, m3u, xtream, fast }

class _SourcesMetrics {
  const _SourcesMetrics({
    required this.padding,
    required this.maxContentWidth,
  });

  final EdgeInsets padding;
  final double maxContentWidth;

  factory _SourcesMetrics.fromWidth(double width) {
    if (width >= 1600) {
      return const _SourcesMetrics(
        padding: EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        maxContentWidth: 1180,
      );
    }
    if (width >= 900) {
      return const _SourcesMetrics(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        maxContentWidth: 1080,
      );
    }
    return const _SourcesMetrics(
      padding: EdgeInsets.all(16),
      maxContentWidth: double.infinity,
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  final xtreamNameController = TextEditingController();
  final xtreamServerController = TextEditingController();
  final xtreamUserController = TextEditingController();
  final xtreamPasswordController = TextEditingController();
  final extraXtreamServerControllers = <TextEditingController>[];

  final m3uTypeFocusNode = FocusNode();
  final xtreamTypeFocusNode = FocusNode();
  final demoTypeFocusNode = FocusNode();
  final nameFocusNode = FocusNode();
  final urlFocusNode = FocusNode();
  final addM3uFocusNode = FocusNode();
  final xtreamNameFocusNode = FocusNode();
  final xtreamServerFocusNode = FocusNode();
  final xtreamUserFocusNode = FocusNode();
  final xtreamPasswordFocusNode = FocusNode();
  final toggleXtreamPasswordFocusNode = FocusNode();
  final addXtreamUrlFocusNode = FocusNode();
  final addXtreamFocusNode = FocusNode();
  final fastPresetFocusNodes = <String, FocusNode>{};

  var formMode = _SourceFormMode.none;
  String? selectedSourceId;
  var showXtreamPassword = false;

  @override
  void initState() {
    super.initState();
    nameFocusNode.onKeyEvent = (node, event) => _handleTextFieldKey(
          event,
          node,
          up: m3uTypeFocusNode,
          down: urlFocusNode,
        );
    urlFocusNode.onKeyEvent = (node, event) => _handleTextFieldKey(
          event,
          node,
          up: nameFocusNode,
          down: addM3uFocusNode,
        );
    addM3uFocusNode.onKeyEvent = (node, event) => _moveFocusOnVerticalKey(
          event,
          up: urlFocusNode,
        );
    xtreamNameFocusNode.onKeyEvent = (node, event) => _handleTextFieldKey(
          event,
          node,
          up: xtreamTypeFocusNode,
          down: xtreamServerFocusNode,
        );
    xtreamServerFocusNode.onKeyEvent = (node, event) => _handleTextFieldKey(
          event,
          node,
          up: xtreamNameFocusNode,
          down: xtreamUserFocusNode,
        );
    xtreamUserFocusNode.onKeyEvent = (node, event) => _handleTextFieldKey(
          event,
          node,
          up: xtreamServerFocusNode,
          down: xtreamPasswordFocusNode,
        );
    xtreamPasswordFocusNode.onKeyEvent = (node, event) => _handleTextFieldKey(
          event,
          node,
          up: xtreamUserFocusNode,
          down: toggleXtreamPasswordFocusNode,
        );
    toggleXtreamPasswordFocusNode.onKeyEvent =
        (node, event) => _moveFocusOnVerticalKey(
              event,
              up: xtreamPasswordFocusNode,
              down: addXtreamUrlFocusNode,
            );
    addXtreamUrlFocusNode.onKeyEvent = (node, event) => _moveFocusOnVerticalKey(
          event,
          up: toggleXtreamPasswordFocusNode,
          down: addXtreamFocusNode,
        );
    addXtreamFocusNode.onKeyEvent = (node, event) => _moveFocusOnVerticalKey(
          event,
          up: addXtreamUrlFocusNode,
        );
  }

  void _ensureFocusedVisible(FocusNode focusNode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || focusNode.context == null || !focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        focusNode.context!,
        alignment: 0.34,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    xtreamNameController.dispose();
    xtreamServerController.dispose();
    xtreamUserController.dispose();
    xtreamPasswordController.dispose();
    for (final controller in extraXtreamServerControllers) {
      controller.dispose();
    }
    m3uTypeFocusNode.dispose();
    xtreamTypeFocusNode.dispose();
    demoTypeFocusNode.dispose();
    nameFocusNode.dispose();
    urlFocusNode.dispose();
    addM3uFocusNode.dispose();
    xtreamNameFocusNode.dispose();
    xtreamServerFocusNode.dispose();
    xtreamUserFocusNode.dispose();
    xtreamPasswordFocusNode.dispose();
    toggleXtreamPasswordFocusNode.dispose();
    addXtreamUrlFocusNode.dispose();
    addXtreamFocusNode.dispose();
    for (final focusNode in fastPresetFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return PopScope(
          canPop: formMode == _SourceFormMode.none && selectedSourceId == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (selectedSourceId != null) {
              _closeSourceDetail();
              return;
            }
            if (formMode != _SourceFormMode.none) {
              _returnToSourcesOverview();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xff080d10),
            appBar: AppBar(
              title: const Text('Sources'),
              backgroundColor: const Color(0xff0d1418),
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = _SourcesMetrics.fromWidth(constraints.maxWidth);
                return FocusTraversalGroup(
                  child: ListView(
                    padding: metrics.padding,
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: metrics.maxContentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedSource == null)
                                _buildSourcesOverview(context)
                              else
                                _buildSourceDetail(context, _selectedSource!),
                            ],
                          ),
                        ),
                      ),
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

  PlaylistSource? get _selectedSource {
    final sourceId = selectedSourceId;
    if (sourceId == null) return null;
    for (final source in widget.controller.sources) {
      if (source.id == sourceId) return source;
    }
    return null;
  }

  Widget _buildSourcesOverview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add source',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _buildSourceTypeButtons(),
        if (formMode != _SourceFormMode.none &&
            formMode != _SourceFormMode.fast) ...[
          const SizedBox(height: 18),
          _SourceFormPanel(
            child: formMode == _SourceFormMode.m3u
                ? _buildM3uForm(context)
                : _buildXtreamForm(context),
          ),
        ],
        if (formMode == _SourceFormMode.fast) ...[
          const SizedBox(height: 18),
          _SourceFormPanel(child: _buildFastPresetsSection(context)),
        ],
        if (formMode == _SourceFormMode.none) ...[
          const SizedBox(height: 28),
          _buildActiveSourcesSection(context),
        ],
      ],
    );
  }

  Widget _buildFastPresetsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Public FAST presets',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < fastPresets.length; index++)
          FocusTraversalOrder(
            order: NumericFocusOrder(20.0 + index),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index == fastPresets.length - 1 ? 0 : 10,
              ),
              child: _FastPresetRow(
                preset: fastPresets[index],
                enabled: _isPresetEnabled(fastPresets[index]),
                focusNode: _fastPresetFocusNode(fastPresets[index]),
                onPressed: () => widget.controller.togglePreset(
                  fastPresets[index],
                  !_isPresetEnabled(fastPresets[index]),
                ),
                onArrowUp: index == 0
                    ? () => demoTypeFocusNode.requestFocus()
                    : () => _fastPresetFocusNode(
                          fastPresets[index - 1],
                        ).requestFocus(),
                onArrowDown: index == fastPresets.length - 1
                    ? null
                    : () => _fastPresetFocusNode(
                          fastPresets[index + 1],
                        ).requestFocus(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveSourcesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active sources',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (widget.controller.sources.isEmpty)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('No sources yet'),
            subtitle: Text('Add an M3U playlist, Xtream source, or demo FAST.'),
          )
        else
          for (final source in widget.controller.sources)
            FocusTraversalOrder(
              order: NumericFocusOrder(
                40.0 + widget.controller.sources.indexOf(source),
              ),
              child: ListTile(
                leading: Icon(
                  source.enabled
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text(source.name),
                subtitle: Text(
                  _sourceSubtitle(source),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSourceDetail(source),
              ),
            ),
      ],
    );
  }

  Widget _buildSourceDetail(BuildContext context, PlaylistSource source) {
    final sourceError = widget.controller.sourceErrorMessages[source.id];
    final sourceTest = widget.controller.sourceTestResults[source.id];
    final channelCount = widget.controller.channelCountForSource(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: _closeSourceDetail,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SourceFormPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceMetaRow('Type', _sourceTypeLabel(source.type)),
              _SourceMetaRow('Status', source.enabled ? 'Enabled' : 'Disabled'),
              _SourceMetaRow('Channels', channelCount.toString()),
              if (source.type != PlaylistSourceType.xtream)
                _SourceMetaRow('URL', source.url),
              if (source.username != null)
                _SourceMetaRow('Username', source.username!),
              if (source.type == PlaylistSourceType.xtream) ...[
                const SizedBox(height: 14),
                Text(
                  'Server URLs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                for (final serverUrl in source.serverUrls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.dns, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            serverUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (sourceError != null) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xff2b1b1d),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xff7c3b42)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Color(0xfff2cf66),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sourceError,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (sourceTest != null) ...[
                const SizedBox(height: 14),
                _SourceTestResultPanel(result: sourceTest),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FormActionButton(
              icon: Icons.refresh,
              label: 'Refresh source',
              onPressed: widget.controller.isLoading
                  ? null
                  : () => widget.controller.refreshSource(source),
            ),
            _FormActionButton(
              icon: Icons.network_check,
              label: 'Test source',
              onPressed: widget.controller.isLoading
                  ? null
                  : () => widget.controller.testSource(source),
            ),
            _FormActionButton(
              icon: source.enabled ? Icons.pause_circle : Icons.play_circle,
              label: source.enabled ? 'Disable source' : 'Enable source',
              onPressed: widget.controller.isLoading
                  ? null
                  : () => widget.controller.setSourceEnabled(
                        source,
                        !source.enabled,
                      ),
            ),
            _FormActionButton(
              icon: Icons.delete,
              label: 'Delete source',
              onPressed: widget.controller.isLoading
                  ? null
                  : () => _deleteSource(source),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceTypeButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final choices = [
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: _SourceTypeButton(
              icon: Icons.add_link,
              title: 'Add M3U',
              subtitle: 'Playlist URL',
              focusNode: m3uTypeFocusNode,
              selected: formMode == _SourceFormMode.m3u,
              autofocus: true,
              onFocused: () => _selectModeFromTypeFocus(_SourceFormMode.m3u),
              onPressed: () => _selectMode(_SourceFormMode.m3u),
              onArrowDown: formMode == _SourceFormMode.m3u
                  ? () => nameFocusNode.requestFocus()
                  : null,
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: _SourceTypeButton(
              icon: Icons.dns,
              title: 'Add Xtream',
              subtitle: 'Server login',
              focusNode: xtreamTypeFocusNode,
              selected: formMode == _SourceFormMode.xtream,
              onFocused: () => _selectModeFromTypeFocus(_SourceFormMode.xtream),
              onPressed: () => _selectMode(_SourceFormMode.xtream),
              onArrowDown: formMode == _SourceFormMode.xtream
                  ? () => xtreamNameFocusNode.requestFocus()
                  : null,
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(3),
            child: _SourceTypeButton(
              icon: Icons.hub,
              title: 'Demo FAST',
              subtitle: 'Choose provider',
              focusNode: demoTypeFocusNode,
              selected: formMode == _SourceFormMode.fast,
              onFocused: () => _selectModeFromTypeFocus(_SourceFormMode.fast),
              onPressed: () => _selectMode(_SourceFormMode.fast),
              onArrowDown: formMode == _SourceFormMode.fast
                  ? () => _fastPresetFocusNode(fastPresets.first).requestFocus()
                  : null,
            ),
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (final choice in choices) ...[
                choice,
                if (choice != choices.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final choice in choices) ...[
              Expanded(child: choice),
              if (choice != choices.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildM3uForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'M3U playlist',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(10),
          child: TextField(
            autofocus: false,
            focusNode: nameFocusNode,
            controller: nameController,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => urlFocusNode.requestFocus(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Name',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(11),
          child: TextField(
            autofocus: false,
            focusNode: urlFocusNode,
            controller: urlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addM3uSource(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Playlist URL',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(12),
          child: _FormActionButton(
            icon: Icons.add,
            label: 'Add M3U source',
            focusNode: addM3uFocusNode,
            onPressed: _addM3uSource,
          ),
        ),
      ],
    );
  }

  Widget _buildXtreamForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xtream Codes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(10),
          child: TextField(
            autofocus: false,
            focusNode: xtreamNameFocusNode,
            controller: xtreamNameController,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => xtreamServerFocusNode.requestFocus(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Name',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(11),
          child: TextField(
            autofocus: false,
            focusNode: xtreamServerFocusNode,
            controller: xtreamServerController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => xtreamUserFocusNode.requestFocus(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Primary server URL',
            ),
          ),
        ),
        for (var index = 0;
            index < extraXtreamServerControllers.length;
            index++) ...[
          const SizedBox(height: 12),
          TextField(
            controller: extraXtreamServerControllers[index],
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Backup server URL ${index + 1}',
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _removeXtreamServerUrl(index),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(12),
          child: TextField(
            autofocus: false,
            focusNode: xtreamUserFocusNode,
            controller: xtreamUserController,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => xtreamPasswordFocusNode.requestFocus(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Username',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(13),
          child: TextField(
            autofocus: false,
            focusNode: xtreamPasswordFocusNode,
            controller: xtreamPasswordController,
            obscureText: !showXtreamPassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Password',
              suffixIcon: Icon(
                showXtreamPassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FocusTraversalOrder(
          order: const NumericFocusOrder(14),
          child: _PasswordVisibilityToggle(
            value: showXtreamPassword,
            focusNode: toggleXtreamPasswordFocusNode,
            onChanged: (value) {
              setState(() => showXtreamPassword = value);
              toggleXtreamPasswordFocusNode.requestFocus();
            },
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(15),
          child: _FormActionButton(
            icon: Icons.add_link,
            label: 'Add server URL',
            focusNode: addXtreamUrlFocusNode,
            onPressed: _addXtreamServerUrl,
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: const NumericFocusOrder(16),
          child: _FormActionButton(
            icon: Icons.add,
            label: 'Add Xtream source',
            focusNode: addXtreamFocusNode,
            onPressed: _addXtreamSource,
          ),
        ),
      ],
    );
  }

  void _selectMode(_SourceFormMode mode) {
    setState(() => formMode = mode);
    if (mode == _SourceFormMode.fast && fastPresets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final focusNode = _fastPresetFocusNode(fastPresets.first);
        focusNode.requestFocus();
        _ensureFocusedVisible(focusNode);
      });
    }
  }

  void _selectModeFromTypeFocus(_SourceFormMode mode) {
    if (formMode == _SourceFormMode.none || formMode == mode) return;
    _selectMode(mode);
  }

  FocusNode _fastPresetFocusNode(PlaylistSource preset) {
    return fastPresetFocusNodes.putIfAbsent(preset.id, FocusNode.new);
  }

  void _returnToSourcesOverview() {
    setState(() => formMode = _SourceFormMode.none);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      m3uTypeFocusNode.requestFocus();
    });
  }

  KeyEventResult _moveFocusOnVerticalKey(
    KeyEvent event, {
    FocusNode? up,
    FocusNode? down,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (up != null) {
        up.requestFocus();
        _ensureFocusedVisible(up);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (down != null) {
        down.requestFocus();
        _ensureFocusedVisible(down);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleTextFieldKey(
    KeyEvent event,
    FocusNode focusNode, {
    FocusNode? up,
    FocusNode? down,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.select) {
      focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return KeyEventResult.handled;
    }
    return _moveFocusOnVerticalKey(event, up: up, down: down);
  }

  Future<void> _addM3uSource() async {
    final url = urlController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    final xtreamInput = XtreamSourceInput.tryParse(url);
    if (xtreamInput != null) {
      _fillXtreamFromInput(xtreamInput);
      return;
    }
    await widget.controller.addM3uSource(nameController.text, url);
    nameController.clear();
    urlController.clear();
    setState(() => formMode = _SourceFormMode.none);
  }

  Future<void> _addXtreamSource() async {
    final added = await widget.controller.addXtreamSource(
      name: xtreamNameController.text,
      serverUrls: _xtreamServerUrls(),
      username: xtreamUserController.text,
      password: xtreamPasswordController.text,
    );
    if (!added) return;
    _clearXtreamForm();
    setState(() => formMode = _SourceFormMode.none);
  }

  void _fillXtreamFromInput(XtreamSourceInput input) {
    xtreamNameController.text = nameController.text.trim().isEmpty
        ? 'Xtream source'
        : nameController.text.trim();
    xtreamServerController.text = input.serverUrl;
    xtreamUserController.text = input.username;
    xtreamPasswordController.text = input.password;
    nameController.clear();
    urlController.clear();
    setState(() => formMode = _SourceFormMode.xtream);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) addXtreamFocusNode.requestFocus();
    });
  }

  void _addXtreamServerUrl() {
    setState(() {
      extraXtreamServerControllers.add(TextEditingController());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || addXtreamUrlFocusNode.context == null) return;
      Scrollable.ensureVisible(
        addXtreamUrlFocusNode.context!,
        alignment: 0.34,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _removeXtreamServerUrl(int index) {
    setState(() {
      extraXtreamServerControllers.removeAt(index).dispose();
    });
  }

  List<String> _xtreamServerUrls() {
    return [
      xtreamServerController.text,
      for (final controller in extraXtreamServerControllers) controller.text,
    ];
  }

  void _clearXtreamForm() {
    xtreamNameController.clear();
    xtreamServerController.clear();
    xtreamUserController.clear();
    xtreamPasswordController.clear();
    showXtreamPassword = false;
    for (final controller in extraXtreamServerControllers) {
      controller.dispose();
    }
    extraXtreamServerControllers.clear();
  }

  bool _isPresetEnabled(PlaylistSource preset) {
    for (final source in widget.controller.sources) {
      if (source.id == preset.id) return source.enabled;
    }
    return false;
  }

  String _sourceSubtitle(PlaylistSource source) {
    final error = widget.controller.sourceErrorMessages[source.id];
    if (error != null) return 'Needs attention';
    final count = widget.controller.channelCountForSource(source);
    final status = source.enabled ? 'Enabled' : 'Disabled';
    return '$status - ${_sourceTypeLabel(source.type)} - $count channels';
  }

  String _sourceTypeLabel(PlaylistSourceType type) {
    return switch (type) {
      PlaylistSourceType.fastPreset => 'Public FAST',
      PlaylistSourceType.m3uUrl => 'M3U playlist',
      PlaylistSourceType.xtream => 'Xtream Codes',
    };
  }

  void _openSourceDetail(PlaylistSource source) {
    setState(() {
      formMode = _SourceFormMode.none;
      selectedSourceId = source.id;
    });
  }

  void _closeSourceDetail() {
    setState(() => selectedSourceId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      m3uTypeFocusNode.requestFocus();
    });
  }

  Future<void> _deleteSource(PlaylistSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${source.name}?'),
          content: const Text(
            'This removes the source and its cached channels from the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await widget.controller.deleteSource(source);
    if (!mounted) return;
    _closeSourceDetail();
  }
}

class _SourceMetaRow extends StatelessWidget {
  const _SourceMetaRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff9aabb2),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTestResultPanel extends StatelessWidget {
  const _SourceTestResultPanel({required this.result});

  final SourceTestResult result;

  @override
  Widget build(BuildContext context) {
    final color =
        result.success ? const Color(0xff78e0b1) : const Color(0xfff2cf66);
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            result.success ? const Color(0xff10251d) : const Color(0xff2b2513),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.warning_amber,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      result.message,
                      if (result.latency != null)
                        _latencyLabel(result.latency!),
                    ].join(' - '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            if (result.servers.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final server in result.servers)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        server.success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: server.success
                            ? const Color(0xff78e0b1)
                            : const Color(0xfff2cf66),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${server.url} - ${server.message} - ${_latencyLabel(server.latency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _latencyLabel(Duration latency) {
    return '${latency.inMilliseconds} ms';
  }
}

class _FastPresetRow extends StatefulWidget {
  const _FastPresetRow({
    required this.preset,
    required this.enabled,
    required this.focusNode,
    required this.onPressed,
    this.onArrowUp,
    this.onArrowDown,
  });

  final PlaylistSource preset;
  final bool enabled;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;

  @override
  State<_FastPresetRow> createState() => _FastPresetRowState();
}

class _FastPresetRowState extends State<_FastPresetRow> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final foreground =
        hasFocus ? const Color(0xff06110c) : const Color(0xfff2f7f4);
    final secondary =
        hasFocus ? const Color(0xff254737) : const Color(0xff9aabb2);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => hasFocus = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.onArrowUp?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onArrowDown?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        canRequestFocus: false,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: hasFocus ? const Color(0xffeefcf4) : const Color(0xff0d171c),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus ? Colors.white : const Color(0xff263842),
              width: hasFocus ? 3 : 1,
            ),
            boxShadow: hasFocus
                ? const [
                    BoxShadow(
                      color: Color(0x664de1a0),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.enabled ? Icons.check_circle : Icons.add_circle_outline,
                color: widget.enabled ? const Color(0xff78e0b1) : foreground,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.preset.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.enabled ? 'On' : 'Off',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
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

class _SourceTypeButton extends StatefulWidget {
  const _SourceTypeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
    this.onFocused,
    this.onArrowDown,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback onPressed;
  final bool autofocus;
  final VoidCallback? onFocused;
  final VoidCallback? onArrowDown;

  @override
  State<_SourceTypeButton> createState() => _SourceTypeButtonState();
}

class _SourceTypeButtonState extends State<_SourceTypeButton> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final focusedOrSelected = hasFocus || widget.selected;
    final foreground =
        hasFocus ? const Color(0xff06110c) : const Color(0xfff2f7f4);

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.arrowDown ||
            widget.onArrowDown == null) {
          return KeyEventResult.ignored;
        }
        widget.onArrowDown!();
        return KeyEventResult.handled;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasFocus
              ? const Color(0xffeefcf4)
              : widget.selected
                  ? const Color(0xff18382d)
                  : const Color(0xff101a20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focusedOrSelected ? Colors.white : const Color(0xff263842),
            width: hasFocus ? 3 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            setState(() => hasFocus = focused);
            if (focused) widget.onFocused?.call();
          },
          onTap: widget.onPressed,
          child: Row(
            children: [
              Icon(widget.icon, color: foreground, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _FormActionButton extends StatefulWidget {
  const _FormActionButton({
    required this.icon,
    required this.label,
    this.focusNode,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  @override
  State<_FormActionButton> createState() => _FormActionButtonState();
}

class _FormActionButtonState extends State<_FormActionButton> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final foreground = hasFocus
        ? const Color(0xff06110c)
        : enabled
            ? const Color(0xfff2f7f4)
            : const Color(0xff64757d);

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        canRequestFocus: enabled,
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => hasFocus = focused),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: hasFocus
                ? const Color(0xffeefcf4)
                : enabled
                    ? const Color(0xff18382d)
                    : const Color(0xff101a20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasFocus
                  ? Colors.white
                  : enabled
                      ? const Color(0xff78e0b1)
                      : const Color(0xff263842),
              width: hasFocus ? 3 : 1,
            ),
            boxShadow: hasFocus
                ? const [
                    BoxShadow(
                      color: Color(0x664de1a0),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: foreground),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
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

class _PasswordVisibilityToggle extends StatefulWidget {
  const _PasswordVisibilityToggle({
    required this.value,
    required this.focusNode,
    required this.onChanged,
  });

  final bool value;
  final FocusNode focusNode;
  final ValueChanged<bool> onChanged;

  @override
  State<_PasswordVisibilityToggle> createState() =>
      _PasswordVisibilityToggleState();
}

class _PasswordVisibilityToggleState extends State<_PasswordVisibilityToggle> {
  var hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final foreground =
        hasFocus ? const Color(0xff06110c) : const Color(0xfff2f7f4);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => hasFocus = focused),
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: hasFocus ? const Color(0xffeefcf4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFocus ? Colors.white : Colors.transparent,
            width: hasFocus ? 3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: widget.value,
              visualDensity: VisualDensity.compact,
              onChanged: (value) => widget.onChanged(value ?? false),
            ),
            const SizedBox(width: 4),
            Text(
              'Show password',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceFormPanel extends StatelessWidget {
  const _SourceFormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff101a20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff263842)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
