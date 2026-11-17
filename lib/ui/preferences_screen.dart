import 'dart:async';

import 'package:flutter/material.dart';

import '../data/growth_photo_files.dart';
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

  Future<void> _deleteAccountAndData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Delete your account?'),
        content: const Text(
          'Your account and all plant data, on this device and in the cloud, '
          'will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = widget.auth;
    if (auth == null || !auth.signedIn) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await auth.deleteAccount();
      final photos = widget.store.garden.growthPhotos;
      final cleared = await widget.store.replaceGarden(
        const Garden(),
        syncCloud: false,
      );
      if (!cleared) throw StateError('Local garden could not be cleared.');
      await GrowthPhotoFiles.deleteFiles(photos);
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
            const SizedBox(height: 24),
            Text('Reminders', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notifications'),
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
            const SizedBox(height: 8),
            Text(
              legacy
                  ? 'Applies to future checks. Custom and older check times stay as they are.'
                  : 'Applies to future checks. Custom check times stay as they are.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
                        'Allow notifications in Android settings to get reminders.',
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
            if (widget.auth?.signedIn == true) ...[
              const SizedBox(height: 24),
              Text('Data & privacy', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Delete account',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('Removes your account and all plants'),
                  onTap: _busy ? null : _deleteAccountAndData,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
