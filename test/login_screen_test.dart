import 'package:bloom/data/auth_service.dart';
import 'package:bloom/data/cloud_garden_sync.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthService extends AuthService {
  FakeAuthService() : super();

  @override
  bool get configured => true;

  @override
  bool get googleConfigured => true;

  @override
  Future<bool> signInWithGoogle() async => false;

  @override
  Future<bool> signInWithEmail(String email, String password) async => false;

  @override
  Future<EmailAuthResult> registerWithEmail(
    String email,
    String password,
  ) async => EmailAuthResult.signedIn;
}

Widget loginApp() {
  final store = GardenStore(garden: const Garden(), persist: (_) async {});
  return MaterialApp(
    home: LoginScreen(
      auth: FakeAuthService(),
      cloudSync: CloudGardenSync(),
      store: store,
    ),
  );
}

void main() {
  testWidgets('offers Google and email authentication together', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(loginApp());

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(SegmentedButton<bool>, 'Create account'),
    );
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('rejects invalid email/password input before submitting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(loginApp());

    await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    final submit = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
  });
}
