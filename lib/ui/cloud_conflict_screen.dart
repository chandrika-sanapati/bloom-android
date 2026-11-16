import 'package:flutter/material.dart';

import '../data/cloud_garden_sync.dart';
import '../domain/garden_store.dart';

class CloudConflictScreen extends StatefulWidget {
  const CloudConflictScreen({
    super.key,
    required this.store,
    required this.sync,
  });

  final GardenStore store;
  final CloudGardenSync sync;

  @override
  State<CloudConflictScreen> createState() => _CloudConflictScreenState();
}

class _CloudConflictScreenState extends State<CloudConflictScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _keepLocal() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await widget.sync.resolveConflictKeepLocal(
      widget.store.garden,
    );
    if (!mounted) return;
    if (result == CloudSyncResult.synced) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _message = widget.sync.message.value ?? 'Cloud data changed again.';
      });
    }
  }

  Future<void> _useCloud() async {
    final cloud = await widget.sync.cloudGarden();
    if (!mounted) return;
    if (cloud == null) {
      setState(() => _message = 'The cloud garden is no longer available.');
      return;
    }
    setState(() => _busy = true);
    final saved = await widget.store.replaceGarden(cloud);
    if (!mounted) return;
    if (saved) {
      widget.sync.clearConflict();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _message = 'The cloud garden could not be saved on this device.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a garden')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your gardens are different',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bloom found a local garden and a different cloud garden. Choose '
            'which one should become the current garden. Nothing is replaced automatically.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _keepLocal,
            child: const Text('Keep this device’s garden'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _useCloud,
            child: const Text('Use the cloud garden'),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
