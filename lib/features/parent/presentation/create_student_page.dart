import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/user_role.dart';
import '../../../core/theme/brand_colors.dart';

class CreateStudentPage extends StatefulWidget {
  const CreateStudentPage({super.key});

  @override
  State<CreateStudentPage> createState() => _CreateStudentPageState();
}

class _CreateStudentPageState extends State<CreateStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateStudent() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parentUser = FirebaseAuth.instance.currentUser;
    if (parentUser == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final rawUsername = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('createStudent');
      await callable({
        'displayName': name,
        'username': rawUsername,
        'password': password,
      });

      if (!mounted) return;
      context.go(FypRoutes.parent);
    } catch (e) {
      debugPrint("createStudent callable error: $e");
      try {
        final studentEmail = '$rawUsername@students.fyp.invalid';
        final newStudentDoc = FirebaseFirestore.instance.collection(FirestorePaths.users).doc();

        await newStudentDoc.set({
          'uid': newStudentDoc.id,
          'username': rawUsername,
          'email': studentEmail,
          'displayName': name,
          'role': UserRole.student.name,
          'parentId': parentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        context.go(FypRoutes.parent);
      } catch (firestoreErr) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to create student account: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(FypRoutes.parent),
        ),
        title: const Text('Add Student / Child'),
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
                    Image.asset('assets/logo.png', height: 100),
                    const SizedBox(height: 20),
                    Text(
                      'Create Student Account',
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
                        child: Text(_errorMessage!, style: const TextStyle(color: BrandColors.error, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Student's Full Name",
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter student's name" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username (for student login)',
                        hintText: 'e.g. john_doe',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(val)) {
                          return 'Username must be 3-20 lowercase alphanumeric characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleCreateStudent,
                      style: FilledButton.styleFrom(
                        backgroundColor: BrandColors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Student Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
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
