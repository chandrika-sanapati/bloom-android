import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EmailAuthResult { signedIn, confirmationRequired }

class AuthService {
  // Keep the public configuration name while retaining private state.
  AuthService({String? webClientId})
    // ignore: prefer_initializing_formals
    : _webClientId = webClientId;

  final String? _webClientId;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _initialized = false;

  bool get configured => _supabaseReady;
  bool get googleConfigured => _webClientId?.isNotEmpty == true && configured;

  bool get signedIn =>
      _supabaseReady && Supabase.instance.client.auth.currentSession != null;

  String? get email =>
      _supabaseReady ? Supabase.instance.client.auth.currentUser?.email : null;

  Stream<AuthState>? get authStateChanges =>
      _supabaseReady ? Supabase.instance.client.auth.onAuthStateChange : null;

  bool get _supabaseReady {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initialize() async {
    if (_initialized || !configured) return;
    await _google.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  Future<bool> signInWithGoogle() async {
    if (!googleConfigured) return false;
    await _initialize();
    if (!_google.supportsAuthenticate()) return false;
    final account = await _google.authenticate();
    final authentication = account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) return false;

    final scopes = const ['email', 'profile'];
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    final accessToken = authorization.accessToken;
    if (accessToken.isEmpty) {
      throw const AuthException('Google did not return an access token.');
    }
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return signedIn;
  }

  Future<bool> signInWithEmail(String email, String password) async {
    if (!configured) return false;
    await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return signedIn;
  }

  Future<EmailAuthResult> registerWithEmail(
    String email,
    String password,
  ) async {
    if (!configured) {
      throw const AuthException('Cloud authentication is not configured.');
    }
    final response = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.session == null
        ? EmailAuthResult.confirmationRequired
        : EmailAuthResult.signedIn;
  }

  Future<bool> verifyEmailOtp(String email, String token) async {
    if (!configured) return false;
    final response = await Supabase.instance.client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
    return response.session != null || signedIn;
  }

  Future<void> resendEmailOtp(String email) async {
    if (!configured) {
      throw const AuthException('Cloud authentication is not configured.');
    }
    await Supabase.instance.client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  Future<void> signOut() async {
    if (!configured) return;
    await Supabase.instance.client.auth.signOut();
    await _google.signOut();
  }

  Future<void> clearLocalSession() async {
    if (!configured) return;
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      try {
        await _google.signOut();
      } catch (_) {
        // The Supabase local session is the authoritative app session.
      }
    }
  }

  Future<void> deleteAccount() async {
    if (!configured || !signedIn) {
      throw const AuthException('No signed-in account is available.');
    }
    final response = await Supabase.instance.client.functions.invoke(
      'delete-account',
    );
    if (response.status < 200 || response.status >= 300) {
      throw const AuthException(
        'Your account data could not be deleted. Nothing was removed.',
      );
    }
    // The server-side deletion invalidates this session. Do not make a second
    // network sign-out request after the user has been deleted.
    await clearLocalSession();
  }
}

AuthService? configuredAuthService() {
  const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  return AuthService(webClientId: webClientId);
}
