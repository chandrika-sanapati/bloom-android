import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Keep the public configuration name while retaining private state.
  AuthService({String? webClientId})
    // ignore: prefer_initializing_formals
    : _webClientId = webClientId;

  final String? _webClientId;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _initialized = false;

  bool get configured => _webClientId?.isNotEmpty == true && _supabaseReady;

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
    if (!configured) return false;
    await _initialize();
    if (!_google.supportsAuthenticate()) return false;
    final account = await _google.authenticate();
    final authentication = account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) return false;

    final authorization = await account.authorizationClient
        .authorizationForScopes(const ['email', 'profile']);
    final accessToken = authorization?.accessToken;
    if (accessToken == null) return false;
    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return signedIn;
  }

  Future<void> signOut() async {
    if (!configured) return;
    await Supabase.instance.client.auth.signOut();
    await _google.signOut();
  }
}

AuthService? configuredAuthService() {
  const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  if (webClientId.isEmpty) return null;
  return AuthService(webClientId: webClientId);
}
