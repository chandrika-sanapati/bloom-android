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
  bool _confirmationRequired = false;
  bool _showPasswordGuidance = false;
  bool _obscurePassword = true;
  String? _message;
  bool _messageIsError = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmationCode = TextEditingController();

  int get _passwordStrength {
    final password = _password.text;
    return [
      password.length >= 8,
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'\d').hasMatch(password),
    ].where((matches) => matches).length;
  }

  String get _passwordStrengthLabel => switch (_passwordStrength) {
    0 => 'Password strength: enter a password',
    1 => 'Password strength: weak',
    2 => 'Password strength: fair',
    3 => 'Password strength: good',
    _ => 'Password strength: strong',
  };

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmationCode.dispose();
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
          setState(() => _message = 'Signed in.');
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
    final validPassword = _register
        ? _passwordStrength == 4
        : password.isNotEmpty;
    if (!email.contains('@') || !validPassword) {
      setState(() {
        _showPasswordGuidance = _register && !validPassword;
        _message = !email.contains('@')
            ? 'Enter a valid email.'
            : _register
            ? null
            : 'Enter a valid email and password.';
      });
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
            _confirmationRequired = true;
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
        setState(() => _message = 'Signed in.');
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

  Future<void> _verifyEmail() async {
    if (_busy) return;
    final code = _confirmationCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _message = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final verified = await widget.auth.verifyEmailOtp(_email.text, code);
      if (!verified) {
        throw const AuthException(
          'That confirmation code could not be verified.',
        );
      }
      if (!mounted) return;
      final sync = await widget.cloudSync.sync(widget.store.garden);
      if (!mounted) return;
      if (sync == CloudSyncResult.failed) {
        setState(() => _message = 'Account confirmed.');
      }
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'We could not verify that code. Check it and try again.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _resendEmailOtp() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.auth.resendEmailOtp(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'A new confirmation code was sent.';
        _messageIsError = false;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'We could not send a new code. Try again shortly.';
        _messageIsError = true;
      });
    }
  }

  void _backToRegistration() {
    setState(() {
      _confirmationRequired = false;
      _confirmationCode.clear();
      _message = null;
      _messageIsError = true;
    });
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
        leading: _confirmationRequired
            ? BackButton(onPressed: _backToRegistration)
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_confirmationRequired) ...[
            const SizedBox(height: 72),
            Icon(
              Icons.mark_email_read_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Check your email',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a 6-digit confirmation code to ${_email.text.trim()}. '
              'Enter it below to confirm your account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmationCode,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyEmail(),
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirmation code',
                hintText: '123456',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _verifyEmail,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_busy ? 'Verifying…' : 'Verify email'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _resendEmailOtp,
              child: const Text('Send code again'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _messageIsError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/bloom_logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
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
                onChanged: (_) => setState(() {
                  if (_passwordStrength == 4) _showPasswordGuidance = false;
                }),
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              if (_register) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Password strength', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _passwordStrength / 4,
                        minHeight: 6,
                        semanticsLabel: _passwordStrengthLabel,
                      ),
                    ),
                  ],
                ),
                if (_showPasswordGuidance) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use 8+ characters with uppercase, lowercase, and a number.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Continue without an account'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
