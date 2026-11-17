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
  bool _register = false;
  bool _obscurePassword = true;
  String? _message;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

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
        if (sync == CloudSyncResult.failed) {
          setState(
            () => _message =
                'Signed in. Your garden is saved locally and will sync when available.',
          );
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

  Future<void> _submitEmail() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      setState(
        () => _message =
            'Enter a valid email and a password with at least 6 characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final result = await widget.auth.registerWithEmail(email, password);
        if (!mounted) return;
        if (result == EmailAuthResult.confirmationRequired) {
          setState(() {
            _busy = false;
            _message =
                'Check your email to confirm your account, then return here to sign in.';
          });
          return;
        }
      } else {
        final signedIn = await widget.auth.signInWithEmail(email, password);
        if (!signedIn) {
          throw const AuthException('Email sign-in did not create a session.');
        }
      }
      if (!mounted) return;
      final sync = await widget.cloudSync.sync(widget.store.garden);
      if (!mounted) return;
      if (sync == CloudSyncResult.failed) {
        setState(
          () => _message =
              'Signed in. Your garden is saved locally and will sync when available.',
        );
      }
      Navigator.of(context).pop(true);
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
            'Authentication failed. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Bloom',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
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
          const SizedBox(height: 32),
          if (widget.auth.configured) ...[
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submitEmail,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                _busy
                    ? 'Working…'
                    : _register
                    ? 'Create account'
                    : 'Sign in with email',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _register = !_register;
                      _message = null;
                    }),
              child: Text(
                _register
                    ? 'Already have an account? Sign in'
                    : 'Need an account? Register',
              ),
            ),
          ],
          if (widget.auth.googleConfigured) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.login),
              label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
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
        ],
      ),
    );
  }
}
