import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/brand_colors.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  bool loading = true;
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    final parentUser = FirebaseAuth.instance.currentUser;
    if (parentUser == null) return;

    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .where('parentId', isEqualTo: parentUser.uid)
          .get();

      final studentList = studentSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();



      if (!mounted) return;
      setState(() {
        students = studentList;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go(FypRoutes.entry);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'Parent';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Parent Workspace'),
        
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: BrandColors.navyTint,
                        child: Icon(Icons.family_restroom, color: BrandColors.navy, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $displayName',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.navy),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Manage student accounts, course options, and learning progress',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blueGrey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: BrandColors.navyTint,
                        child: Icon(Icons.subscriptions_outlined, color: BrandColors.navy),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subscriptions & access', style: TextStyle(fontWeight: FontWeight.bold, color: BrandColors.navy, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Review course options and see the checkout interface. Payment processing is disabled for now.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => context.go(FypRoutes.parentSubscriptions),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enrolled Students / Children',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.navy),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go(FypRoutes.parentCreateStudent),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Student'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildStudentList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (students.isEmpty) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.face, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No student accounts created yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click "Add Student" above to register an account for your child.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8EF)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: BrandColors.navyTint,
                      child: Icon(Icons.school, color: BrandColors.navy),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['displayName'] ?? student['email'] ?? 'Student',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(student['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(FypRoutes.parentSubscriptions),
                      child: const Text('Manage Subscriptions'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Learning analytics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BrandColors.navy),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Progress, completed lessons, and learning time will appear here as activity tracking is connected.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
