import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/services/auth_service.dart';
import 'package:social_graph/widgets/sign_in_screen.dart';

/// Records calls and optionally throws an [AuthException]. All overridden
/// methods avoid touching FirebaseAuth, so the base class is never exercised.
class FakeAuthService extends AuthService {
  String? signInEmail;
  String? signInPassword;
  String? registerEmail;
  String? registerPassword;
  int anonymousCalls = 0;

  /// When set, every async method throws this exception.
  AuthException? throwOnCall;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    signInEmail = email;
    signInPassword = password;
    if (throwOnCall != null) throw throwOnCall!;
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    registerEmail = email;
    registerPassword = password;
    if (throwOnCall != null) throw throwOnCall!;
  }

  @override
  Future<void> signInAnonymously() async {
    anonymousCalls++;
    if (throwOnCall != null) throw throwOnCall!;
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeAuthService auth, {
  VoidCallback? onSignedIn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SignInScreen(auth: auth, onSignedIn: onSignedIn),
    ),
  );
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String email = 'user@example.com',
  String password = 'secret123',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
}

void main() {
  group('SignInScreen', () {
    testWidgets('tapping Sign in with valid input calls signInWithEmail',
        (tester) async {
      final auth = FakeAuthService();
      var signedIn = false;
      await _pumpScreen(tester, auth, onSignedIn: () => signedIn = true);

      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.signInEmail, 'user@example.com');
      expect(auth.signInPassword, 'secret123');
      expect(auth.registerEmail, isNull);
      expect(signedIn, isTrue);
    });

    testWidgets('toggling to register mode calls registerWithEmail',
        (tester) async {
      final auth = FakeAuthService();
      await _pumpScreen(tester, auth);

      // Toggle prompt offers "Create account" while in sign-in mode.
      await tester.tap(find.widgetWithText(TextButton, 'Create account'));
      await tester.pump();

      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(auth.registerEmail, 'user@example.com');
      expect(auth.registerPassword, 'secret123');
      expect(auth.signInEmail, isNull);
    });

    testWidgets('a thrown AuthException renders its message', (tester) async {
      final auth = FakeAuthService()
        ..throwOnCall = const AuthException('Incorrect email or password.');
      var signedIn = false;
      await _pumpScreen(tester, auth, onSignedIn: () => signedIn = true);

      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(signedIn, isFalse);
    });

    testWidgets('invalid email shows local validation error without calling auth',
        (tester) async {
      final auth = FakeAuthService();
      await _pumpScreen(tester, auth);

      await _enterCredentials(tester, email: 'not-an-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(auth.signInEmail, isNull);
    });

    testWidgets('Continue without an account calls signInAnonymously',
        (tester) async {
      final auth = FakeAuthService();
      var signedIn = false;
      await _pumpScreen(tester, auth, onSignedIn: () => signedIn = true);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Continue without an account'),
      );
      await tester.pumpAndSettle();

      expect(auth.anonymousCalls, 1);
      expect(signedIn, isTrue);
    });
  });
}
