import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Full-screen authentication UI. Toggles between sign-in and registration
/// modes, offers an anonymous (guest) sign-in path, validates input locally,
/// and surfaces [AuthException.message] inline on failure.
class SignInScreen extends StatefulWidget {
  /// Auth backend used for all sign-in/registration calls.
  final AuthService auth;

  /// Invoked once any sign-in path completes successfully.
  final VoidCallback? onSignedIn;

  const SignInScreen({
    super.key,
    required this.auth,
    this.onSignedIn,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // ---- Design tokens (dark theme) ----
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _field = Color(0xFF111111);
  static const Color _border = Color(0xFF333333);
  static const Color _accent = Color(0xFF6366F1);
  static const Color _accentPressed = Color(0xFF4F46E5);
  static const Color _textPrimary = Color(0xFFE2E8F0);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _error = Color(0xFFF87171);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(trimmed);
  }

  /// Local validation before hitting the backend. Returns an error string,
  /// or null when the input is acceptable.
  String? _validateInput() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_isValidEmail(email)) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) {
      return 'Please enter your password.';
    }
    return null;
  }

  Future<void> _submitEmailPassword() async {
    if (_isLoading) return;

    final validationError = _validateInput();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await widget.auth.registerWithEmail(email, password);
      } else {
        await widget.auth.signInWithEmail(email, password);
      }
      if (!mounted) return;
      widget.onSignedIn?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueAnonymously() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.auth.signInAnonymously();
      if (!mounted) return;
      widget.onSignedIn?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleMode() {
    if (_isLoading) return;
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegisterMode ? 'Create account' : 'Sign in';
    final togglePrompt = _isRegisterMode
        ? 'Already have an account?'
        : "Don't have an account?";
    final toggleAction = _isRegisterMode ? 'Sign in' : 'Create account';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Social Graph',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    semanticLabel: 'Email address',
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: '••••••••',
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    semanticLabel: 'Password',
                    onSubmitted: (_) => _submitEmailPassword(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      key: const Key('signin_error'),
                      style: const TextStyle(color: _error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: title,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _submitEmailPassword,
                    accent: _accent,
                    accentPressed: _accentPressed,
                  ),
                  const SizedBox(height: 16),
                  _ModeToggle(
                    prompt: togglePrompt,
                    action: toggleAction,
                    onPressed: _isLoading ? null : _toggleMode,
                    promptColor: _textMuted,
                    actionColor: _accent,
                  ),
                  const SizedBox(height: 24),
                  _Divider(color: _border, labelColor: _textMuted),
                  const SizedBox(height: 24),
                  _GuestButton(
                    onPressed: _isLoading ? null : _continueAnonymously,
                    surface: _surface,
                    border: _border,
                    textColor: _textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String semanticLabel,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: semanticLabel,
          textField: true,
          child: TextField(
            controller: controller,
            enabled: !_isLoading,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            style: const TextStyle(color: _textPrimary, fontSize: 15),
            cursorColor: _accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _field,
              hintText: hint,
              hintStyle: const TextStyle(color: _textMuted),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: _fieldBorder(_border),
              focusedBorder: _fieldBorder(_accent),
              disabledBorder: _fieldBorder(_border),
            ),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color accent;
  final Color accentPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.accent,
    required this.accentPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          disabledBackgroundColor: accentPressed.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback? onPressed;
  final Color promptColor;
  final Color actionColor;

  const _ModeToggle({
    required this.prompt,
    required this.action,
    required this.onPressed,
    required this.promptColor,
    required this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: TextStyle(color: promptColor, fontSize: 13)),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: TextStyle(
              color: actionColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  final Color labelColor;

  const _Divider({required this.color, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(color: labelColor, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 1)),
      ],
    );
  }
}

class _GuestButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color surface;
  final Color border;
  final Color textColor;

  const _GuestButton({
    required this.onPressed,
    required this.surface,
    required this.border,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textColor,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Continue without an account',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
