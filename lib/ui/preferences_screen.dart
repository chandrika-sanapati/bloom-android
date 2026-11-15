import 'package:flutter/material.dart';

import '../data/watering_notifications.dart';
import '../domain/garden_store.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    super.key,
    required this.store,
    required this.notifications,
  });

  final GardenStore store;
  final WateringNotifications notifications;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _update(bool enabled) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    if (enabled && !await widget.notifications.requestPermission()) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Notifications are off in Android settings. Your tasks stay in Bloom.';
      });
      return;
    }
    final saved = await widget.store.setTaskNotifications(enabled);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = saved
          ? null
          : "Your notification preference couldn't be saved.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.store.garden.preferences.taskNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        leadingWidth: 96,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Watering notifications'),
              value: enabled,
              onChanged: _busy ? null : _update,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Bloom only reminds you about future checks. Overdue tasks never create a notification burst.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
