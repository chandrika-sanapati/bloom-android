import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../data/cloud_garden_sync.dart';
import '../domain/garden_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.cloudSync,
    required this.store,
  });

  final AuthService auth;
  final CloudGardenSync cloudSync;
  final GardenStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final signedIn = await widget.auth.signInWithGoogle();
      if (!mounted) return;
      if (signedIn) {
        final sync = await widget.cloudSync.sync(widget.store.garden);
        if (!mounted) return;
        if (sync == CloudSyncResult.conflict) {
          await widget.auth.signOut();
          if (!mounted) return;
          setState(() {
            _busy = false;
            _message =
                'Your account already has a different garden. Bloom did not overwrite local data.';
          });
          return;
        }
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _busy = false;
          _message =
              'Google sign-in is unavailable or was cancelled. Your local garden is still available.';
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Google sign-in failed (${error.runtimeType}). ${error.toString()}'
            '\nYou can continue using Bloom locally.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to Bloom'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Icon(Icons.eco, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Keep your garden with you',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in with Google to prepare for secure cloud features. Bloom '
            'continues to work locally when you are signed out or offline.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: widget.auth.configured && !_busy ? _signIn : null,
            icon: const Icon(Icons.login),
            label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          if (!widget.auth.configured) ...[
            const SizedBox(height: 12),
            Text(
              'Cloud sign-in is not configured in this build. Run Bloom with '
              'the Supabase and Google build-time settings to enable it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          if (!widget.auth.configured) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Continue without an account'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Signing in does not replace your local garden automatically. '
            'Cloud merge choices will be shown before sync is enabled.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
