import 'package:flutter/material.dart';

import '../models/playlist_source.dart';
import 'one_tv_player_app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sources')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Add M3U URL', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Playlist URL',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _addSource,
                  icon: const Icon(Icons.add),
                  label: const Text('Add source'),
                ),
              ),
              const SizedBox(height: 28),
              Text('Public FAST presets', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final preset in fastPresets)
                SwitchListTile(
                  title: Text(preset.name),
                  subtitle: Text(preset.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  value: _isPresetEnabled(preset),
                  onChanged: (enabled) => widget.controller.togglePreset(preset, enabled),
                ),
              const SizedBox(height: 28),
              Text('Active sources', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final source in widget.controller.sources)
                ListTile(
                  leading: Icon(source.enabled ? Icons.check_circle : Icons.radio_button_unchecked),
                  title: Text(source.name),
                  subtitle: Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addSource() async {
    final url = urlController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    await widget.controller.addM3uSource(nameController.text, url);
    nameController.clear();
    urlController.clear();
  }

  bool _isPresetEnabled(PlaylistSource preset) {
    for (final source in widget.controller.sources) {
      if (source.id == preset.id) return source.enabled;
    }
    return false;
  }
}
