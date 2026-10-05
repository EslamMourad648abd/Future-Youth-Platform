import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../services/theme_service.dart';
import '../../services/platform_config.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';

  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // FORM
  // ============================================================

  final _formKey =
  GlobalKey<FormState>();

  final _emailCtrl =
  TextEditingController();

  final _passwordCtrl =
  TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _obscure = true;
  bool _isSubmitting = false;

  // ============================================================
  // PASSWORD VISIBILITY
  // ============================================================

  void _togglePassword() {
    setState(() {
      _obscure = !_obscure;
    });
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  Future<void> _resetPassword() async {
    final email =
    _emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your email before resetting password.',
          ),
          backgroundColor:
          Colors.redAccent,
        ),
      );

      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent successfully.',
          ),
          backgroundColor:
          Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Error sending reset email.',
          ),
          backgroundColor:
          Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final email =
      _emailCtrl.text.trim();

      final password =
      _passwordCtrl.text.trim();

      // ========================================================
      // FIREBASE AUTHENTICATION
      // ========================================================

      final credential =
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ========================================================
      // FORCE TOKEN REFRESH
      // ========================================================
      //
      // This ensures the latest custom claims / role are loaded.
      //

      await credential.user!
          .getIdToken(true);

      // ========================================================
      // LOAD USER ROLE
      // ========================================================

      await AuthService.loadUserRole();

      // ========================================================
      // PLATFORM ROLE VALIDATION
      // ========================================================
      
      final config = PlatformConfig.current;
      if (!config.isRoleAllowed(AuthService.role)) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'access-denied',
          message: 'Your account does not have access to the ${config.title}.'
        );
      }

      // ========================================================
      // NAVIGATION
      // ========================================================

      if (mounted) {
        context.go(config.landingRoute);
      }
    } on FirebaseAuthException catch (e) {
      String message =
          e.message ?? 'Login failed.';

      // --------------------------------------------------------
      // FIREBASE ERROR MESSAGES
      // --------------------------------------------------------

      if (e.code == 'user-not-found') {
        message =
        'No user found for this email.';
      }

      if (e.code == 'wrong-password') {
        message =
        'Incorrect password.';
      }

      if (e.code == 'invalid-credential') {
        message =
        'Invalid email or password.';
      }

      if (e.code == 'invalid-email') {
        message =
        'Please enter a valid email address.';
      }

      if (e.code == 'user-disabled') {
        message =
        'This account has been disabled.';
      }

      if (e.code == 'access-denied') {
        message =
            e.message ??
                'Access denied.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          Colors.redAccent,
        ),
      );
    } catch (e) {
      // ========================================================
      // UNEXPECTED ERROR
      // ========================================================

      debugPrint(
        'Login error: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Login failed: $e',
          ),
          backgroundColor:
          Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradientStart = isDark ? const Color(0xFF0F172A) : const Color(0xFF001C38);
    final gradientEnd = isDark ? const Color(0xFF1E293B) : const Color(0xFF80CFFF);

    return Scaffold(
      body: Stack(
        children: [
          // ========================================================
          // BACKGROUND GRADIENT
          // ========================================================
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientStart,
                  gradientEnd,
                ],
              ),
            ),
          ),

          // ========================================================
          // THEME TOGGLE
          // ========================================================
          Positioned(
            top: 20,
            right: 20,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.themeNotifier,
              builder: (context, mode, _) {
                final isCurrentDark = mode == ThemeMode.dark;
                return IconButton(
                  onPressed: ThemeService.toggleTheme,
                  icon: Icon(
                    isCurrentDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white70,
                  ),
                  tooltip: isCurrentDark ? 'Light Mode' : 'Dark Mode',
                );
              },
            ),
          ),

          // ========================================================
          // LOGIN CONTENT
          // ========================================================
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                ),
                child: Card(
                  elevation: 20,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 400;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 24 : 40,
                        vertical: isCompact ? 28 : 36,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ==============================================
                          // LOGO + TITLE
                          // ==============================================
                          Column(
                            children: [
                              Image.asset(
                                PlatformConfig.current.logoAsset,
                                height: isCompact ? 100 : 140,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                PlatformConfig.current.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isCompact ? 19 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xff38BDF8) : const Color(0xFF1F5B8A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                PlatformConfig.current.subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // ==============================================
                          // FORM
                          // ==============================================
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ======================================
                                // EMAIL
                                // ======================================
                                Text(
                                  l10n?.translate('email') ?? 'Email',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF6B7B8B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF6FB),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    hintText: 'Enter your email',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return l10n?.translate('email_required') ?? 'Email is required';
                                    }
                                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                                      return l10n?.translate('valid_email') ?? 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // ======================================
                                // PASSWORD
                                // ======================================
                                Text(
                                  l10n?.translate('password') ?? 'Password',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF6B7B8B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  onFieldSubmitted: (_) { if (!_isSubmitting) _submit(); },
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF6FB),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    hintText: 'Enter your password',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      onPressed: _togglePassword,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return l10n?.translate('password_required') ?? 'Password is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

                                // ======================================
                                // LOGIN BUTTON
                                // ======================================
                                ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38BDF8),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text(
                                          l10n?.translate('login') ?? 'Login',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),

                                // ======================================
                                // FORGOT PASSWORD
                                // ======================================
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _isSubmitting ? null : _resetPassword,
                                  child: Text(
                                    l10n?.translate('forgot_password') ?? 'Forgot Password?',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xff38BDF8) : const Color(0xFF1F5B8A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
