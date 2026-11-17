import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/auth_service.dart';
import '../data/cloud_garden_sync.dart';
import '../data/watering_notifications.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'login_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    super.key,
    required this.store,
    required this.notifications,
    this.auth,
    required this.cloudSync,
  });
  final GardenStore store;
  final WateringNotifications notifications;
  final AuthService? auth;
  final CloudGardenSync cloudSync;
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.notifications.refreshPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.notifications.refreshPermission());
    }
  }

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
            'Notifications are off in Android settings. Your checks stay in Bloom.';
      });
      return;
    }
    final saved = await widget.store.setTaskNotifications(enabled);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = saved
          ? null
          : "Your notification preference couldn't be saved. Try again.";
    });
  }

  Future<void> _chooseTime() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final preferences = widget.store.garden.preferences;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.reminderHour,
        minute: preferences.reminderMinute,
      ),
    );
    if (!mounted) return;
    final saved =
        chosen == null ||
        await widget.store.setReminderTime(chosen.hour, chosen.minute);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = saved
          ? null
          : "Your reminder time couldn't be saved. Try again.";
    });
  }

  Future<void> _openNotificationSettings() async {
    final opened = await launchUrl(Uri.parse('app-settings:'));
    if (!opened && mounted) {
      setState(() {
        _message =
            "Android settings couldn't be opened. You can enable notifications in the app's system settings.";
      });
    }
  }

  Future<void> _deleteAllData() async {
    final firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all Bloom data?'),
        content: const Text(
          'This permanently deletes your cloud account, cloud garden, and '
          'local garden from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirmation != true || !mounted) return;

    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete everything permanently?'),
        content: const Text(
          'Your account and all saved plant data will be erased. There is no '
          'recovery option after deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (finalConfirmation != true || !mounted) return;

    final auth = widget.auth;
    if (auth == null || !auth.signedIn) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await auth.deleteAccount();
      final cleared = await widget.store.replaceGarden(const Garden());
      if (!cleared) {
        throw StateError('Local garden could not be cleared.');
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Your account was deleted, but the local garden could not be cleared. Try again.';
      });
    }
  }

  Future<void> _toggleAuth() async {
    final auth = widget.auth;
    if (auth == null || _busy) return;
    if (!auth.signedIn) {
      final signedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            auth: auth,
            cloudSync: widget.cloudSync,
            store: widget.store,
          ),
        ),
      );
      if (!mounted || signedIn != true) return;
      setState(() {});
      return;
    }
    final signOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of Bloom?'),
        content: const Text(
          'Your local garden will stay on this device. Cloud synchronization '
          'will stop until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (signOut != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (auth.signedIn) {
        await auth.signOut();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      } else if (!await auth.signInWithGoogle()) {
        throw StateError('Sign-in was cancelled or unavailable.');
      } else {
        final result = await widget.cloudSync.sync(widget.store.garden);
        if (result == CloudSyncResult.failed) {
          _message =
              'Signed in. Your garden remains saved locally and will retry syncing.';
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Google sign-in was cancelled or unavailable.');
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.store,
      widget.notifications.status,
      widget.notifications.permissionGranted,
      widget.cloudSync.status,
      widget.cloudSync.message,
    ]),
    builder: (context, _) {
      final theme = Theme.of(context);
      final preferences = widget.store.garden.preferences;
      final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(
          hour: preferences.reminderHour,
          minute: preferences.reminderMinute,
        ),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      final legacy = widget.store.garden.schedules.any(
        (s) => s.timeSource == CheckTimeSource.legacy,
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          leading: const BackButton(),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.auth?.configured == true) ...[
              Text('Account', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(
                    widget.auth!.signedIn ? 'Signed in' : 'Sign in to Bloom',
                  ),
                  subtitle: widget.auth!.email == null
                      ? const Text(
                          'Use Google or email and password to save your garden securely.',
                        )
                      : Text(widget.auth!.email!),
                  trailing: widget.auth!.signedIn
                      ? const Icon(Icons.logout)
                      : const Icon(Icons.login),
                  onTap: _busy ? null : _toggleAuth,
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (widget.auth?.signedIn == true) ...[
              Text('Privacy', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _deleteAllData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete all data'),
              ),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 24),
            Text('Preferences', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Watering reminders', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Watering notifications'),
                    value: preferences.taskNotifications,
                    onChanged: _busy ? null : _update,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Reminder time'),
                    subtitle: Text(time),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _chooseTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Applies to automatic checks after today. Custom times and today's checks stay unchanged.",
              style: theme.textTheme.bodyMedium,
            ),
            if (legacy) ...[
              const SizedBox(height: 8),
              Text(
                'Older saved checks keep their time until completed or edited.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Bloom reminds you about future checks only. Android may deliver reminders later than the chosen time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!preferences.taskNotifications) ...[
              const SizedBox(height: 8),
              const Text(
                'Turn on watering notifications to receive reminders.',
              ),
            ],
            if (preferences.taskNotifications &&
                widget.notifications.permissionGranted.value == false) ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Android notifications are off',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your watering checks remain available in Bloom. '
                        'Allow notifications in Android settings to receive reminders.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _openNotificationSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open Android settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_message ?? widget.notifications.status.value
                case final String message) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(message, style: theme.textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      );
    },
  );
}
