import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/user_role.dart';
import '../../../core/theme/brand_colors.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 6,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFE2E8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset('assets/logo.png', height: 120),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Future Youth Platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: BrandColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select your portal to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: BrandColors.greenText,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ==============================================
                      // TEACHER SECTION
                      // ==============================================
                      const Text(
                        'Teacher Portal',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BrandColors.navy),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.go(FypRoutes.loginFor(UserRole.teacher)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BrandColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('Teacher Login'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go(FypRoutes.signupFor(UserRole.teacher)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: BrandColors.navy,
                                side: const BorderSide(color: BrandColors.navy),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.person_add_alt_1, size: 18),
                              label: const Text('Teacher Signup'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==============================================
                      // PARENT SECTION
                      // ==============================================
                      const Text(
                        'Parent Portal',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BrandColors.greenText),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.go(FypRoutes.loginFor(UserRole.parent)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BrandColors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('Parent Login'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go(FypRoutes.signupFor(UserRole.parent)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: BrandColors.greenText,
                                side: const BorderSide(color: BrandColors.green),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.person_add_alt_1, size: 18),
                              label: const Text('Parent Signup'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==============================================
                      // STUDENT SECTION
                      // ==============================================
                      const Text(
                        'Student Portal',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BrandColors.navy),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.go(FypRoutes.loginFor(UserRole.student)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.school, size: 18),
                        label: const Text('Student Login'),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '* Student accounts are registered by parents',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 20),

                      // ==============================================
                      // ADMIN SECTION
                      // ==============================================
                      const Divider(),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => context.go(FypRoutes.loginFor(UserRole.admin)),
                          icon: const Icon(Icons.admin_panel_settings, size: 18),
                          label: const Text('Admin Console Login'),
                          style: TextButton.styleFrom(
                            foregroundColor: BrandColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
