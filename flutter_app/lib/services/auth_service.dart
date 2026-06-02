import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin, user-facing auth error wrapper. Carries a message safe to show in UI.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Wraps [FirebaseAuth] so the rest of the app never touches the Firebase SDK
/// directly. Does NOT call Firebase at construction time — all access is lazy.
class AuthService {
  /// Emits the current user on subscription and on every auth state change.
  Stream<User?> get authState => FirebaseAuth.instance.authStateChanges();

  /// The currently signed-in user, or null when signed out.
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Whether a user is currently signed in.
  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  /// Signs in an anonymous (guest) session.
  Future<void> signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      debugPrint('signInAnonymously unexpected error: $e');
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  /// Signs in with an email and password.
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      debugPrint('signInWithEmail unexpected error: $e');
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  /// Registers a new account with an email and password.
  Future<void> registerWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      debugPrint('registerWithEmail unexpected error: $e');
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      debugPrint('signOut unexpected error: $e');
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  /// Permanently deletes the signed-in user's Firebase account, which also
  /// signs them out. Throws an [AuthException] on failure — notably with the
  /// 'requires-recent-login' message when the session is too old and the user
  /// must sign in again before the account can be deleted.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AuthException('You are not signed in.');
    }
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    } catch (e) {
      debugPrint('deleteAccount unexpected error: $e');
      throw const AuthException('Something went wrong. Please try again.');
    }
  }

  /// Maps a [FirebaseAuthException] code to a user-friendly message.
  String _messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'That password is too weak.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'requires-recent-login':
        return 'For your security, sign out and sign in again before '
            'deleting your account.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
