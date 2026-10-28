import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/user_role.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../widgets/appbar_actions.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

class LoginPage extends StatefulWidget {
  final UserRole role;

  const LoginPage({
    super.key,
    required this.role,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final FirebaseAuthRepository _repository = FirebaseAuthRepository();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _repository.signInAs(
        widget.role,
        _identifierController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      context.go(FypRoutes.homeFor(widget.role));
    } on RoleMismatchException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _parseErrorMessage(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('user-not-found')) return 'User not found.';
    if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Invalid email/username or password.';
    }
    if (str.contains('network')) return 'Network error. Please try again.';
    return 'Sign in failed. Please check your credentials.';
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.role == UserRole.student;
    final roleTitle = widget.role.name[0].toUpperCase() + widget.role.name.substring(1);

    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(FypRoutes.entry),
        ),
        title: Text('Sign in as $roleTitle'),
        actions: const [GlobalAppBarActions(iconColor: Colors.white)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/logo.png', height: 120),
                    const SizedBox(height: 24),
                    Text(
                      'Sign in as $roleTitle',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: BrandColors.navy,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BrandColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BrandColors.error),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: BrandColors.error, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        labelText: isStudent ? 'Username' : 'Email Address',
                        prefixIcon: Icon(isStudent ? Icons.person : Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return isStudent ? 'Please enter your username' : 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: BrandColors.navy,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Sign in as $roleTitle', style: const TextStyle(fontSize: 16)),
                    ),
                    if (widget.role.canSelfSignUp) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?"),
                          TextButton(
                            onPressed: () => context.go(FypRoutes.signupFor(widget.role)),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
