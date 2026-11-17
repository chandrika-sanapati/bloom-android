import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../data/cloud_garden_sync.dart';
import '../domain/garden_store.dart';
import 'widgets.dart';

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
  late final _codeFocus = FocusNode()..addListener(() => setState(() {}));
  Timer? _resendTimer;
  int _resendIn = 0;

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

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
    _resendTimer?.cancel();
    _codeFocus.dispose();
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
          _startResendTimer();
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
        _message = 'A new code was sent.';
        _messageIsError = false;
      });
      _startResendTimer();
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

  void _setMode(bool register) => setState(() {
    _register = register;
    _message = null;
    _showPasswordGuidance = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: _confirmationRequired
            ? BackButton(onPressed: _backToRegistration)
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: _confirmationRequired
                    ? _codeView(theme)
                    : _formView(theme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _primaryButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    if (_confirmationRequired) {
      return FilledButton(
        onPressed: _busy ? null : _verifyEmail,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: _busy ? const _Spinner() : const Text('Verify'),
      );
    }
    return FilledButton(
      onPressed: _busy || !widget.auth.configured ? null : _submitEmail,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: _busy
          ? const _Spinner()
          : Text(_register ? 'Create account' : 'Sign in'),
    );
  }

  Widget? _messageText(ThemeData theme) => _message == null
      ? null
      : MessageBanner(_message!, isError: _messageIsError);

  InputDecoration _field(ThemeData theme, String label, IconData icon) =>
      InputDecoration(labelText: label, prefixIcon: Icon(icon));

  List<Widget> _formView(ThemeData theme) {
    final message = _messageText(theme);
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/area-whole.png',
          height: 170,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 24),
      Text('Welcome to Bloom', style: theme.textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text(
        'Calm care for your plants',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
      if (widget.auth.googleConfigured) ...[
        OutlinedButton.icon(
          onPressed: _busy ? null : _signIn,
          icon: const Icon(Icons.account_circle_outlined),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or use email',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (widget.auth.configured) ...[
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Sign in')),
            ButtonSegment(value: true, label: Text('Create account')),
          ],
          selected: {_register},
          onSelectionChanged: _busy ? null : (s) => _setMode(s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: _field(theme, 'Email', Icons.mail_outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !_busy,
          onChanged: (_) => setState(() {
            if (_passwordStrength == 4) _showPasswordGuidance = false;
          }),
          onSubmitted: (_) => _submitEmail(),
          obscureText: _obscurePassword,
          autofillHints: [
            _register ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: _field(theme, 'Password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        if (_register && _password.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _passwordStrength / 4,
              minHeight: 6,
              semanticsLabel: _passwordStrengthLabel,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _passwordStrengthLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_register && _showPasswordGuidance) ...[
          const SizedBox(height: 6),
          Text(
            'Use 8+ characters with uppercase, lowercase, and a number.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ] else
        Text(
          'Cloud sign-in is not configured in this build.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      if (message != null) ...[const SizedBox(height: 16), message],
    ];
  }

  List<Widget> _codeView(ThemeData theme) {
    final message = _messageText(theme);
    final code = _confirmationCode.text;
    return [
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.mark_email_read_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text('Check your email', style: theme.textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
        'Enter the 6-digit code sent to ${_email.text.trim()}',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 28),
      Semantics(
        label: 'Confirmation code',
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.85,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: 2,
                            color:
                                _codeFocus.hasFocus &&
                                    i == code.length.clamp(0, 5)
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _confirmationCode,
                  focusNode: _codeFocus,
                  autofocus: true,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (value) {
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits != value) {
                      _confirmationCode.value = TextEditingValue(
                        text: digits,
                        selection: TextSelection.collapsed(
                          offset: digits.length,
                        ),
                      );
                    }
                    setState(() {});
                    if (digits.length == 6) _verifyEmail();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _busy || _resendIn > 0 ? null : _resendEmailOtp,
          child: Text(
            _resendIn > 0
                ? 'Resend code in 0:${_resendIn.toString().padLeft(2, '0')}'
                : 'Resend code',
          ),
        ),
      ),
      if (message != null) ...[const SizedBox(height: 8), message],
    ];
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2.5),
  );
}
