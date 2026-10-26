import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/brand_colors.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  bool loading = true;
  String selectedSubject = 'All';
  List<Map<String, dynamic>> courses = [];

  final List<String> subjects = [
    'All',
    'Mathematics',
    'Physics',
    'Chemistry',
    'English',
    'Biology',
    'Arabic',
  ];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.courses)
          .where('status', isEqualTo: 'published')
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      final list = snapshot.docs
          .where((doc) => doc.data()['status'] == 'published' && doc.data()['approvalStatus'] == 'approved')
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      if (!mounted) return;
      setState(() {
        courses = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _showEnrollmentInfo(Map<String, dynamic> course) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.family_restroom, color: Theme.of(context).colorScheme.primary, size: 36),
        title: const Text('Ask your parent to enrol'),
        content: Text(
          'Your parent can review subscription options for "${course['title'] ?? 'this course'}" from Parent Workspace. '
          'Checkout is currently a UI preview only; no invoice or payment request will be created.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Understood')),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go(FypRoutes.entry);
  }

  List<Map<String, dynamic>> get _filteredCourses {
    if (selectedSubject == 'All') return courses;
    return courses.where((c) => (c['subject'] ?? '').toString().toLowerCase() == selectedSubject.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'Student';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Student Learning Portal'),
        
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
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
                        backgroundColor: BrandColors.greenTint,
                        child: Icon(Icons.school, color: Theme.of(context).brightness == Brightness.dark ? BrandColors.green : BrandColors.greenText, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $displayName',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Watch 1st free video preview, take quizzes, and learn from top teachers',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Explore by Subject',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: subjects.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sub = subjects[index];
                    final selected = selectedSubject == sub;
                    return ChoiceChip(
                      label: Text(sub),
                      selected: selected,
                      selectedColor: BrandColors.navy,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : BrandColors.navy,
                        fontWeight: selected ? FontWeight.bold : null,
                      ),
                      onSelected: (_) => setState(() => selectedSubject = sub),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildCourseList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseList(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredCourses.isEmpty) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.video_library_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No teacher playlists found for this subject.',
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
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
      itemCount: _filteredCourses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final course = _filteredCourses[index];
        final subject = course['subject'] ?? 'General';
        final schoolYear = course['schoolYear'] ?? 'All Grades';
        final teacherName = course['teacherName'] ?? 'Teacher';

        return Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subject.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrandColors.greenTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        schoolYear,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? BrandColors.green : BrandColors.greenText),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(teacherName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  course['title'] ?? 'Course Title',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                if ((course['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    course['description'],
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.go(FypRoutes.studentCourseFor(course['id'].toString()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.play_arrow, size: 20),
                        label: const Text('1st Free Video Preview'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEnrollmentInfo(course),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandColors.navy,
                          side: const BorderSide(color: Theme.of(context).colorScheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.receipt, size: 18),
                        label: const Text('Subscription Info'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
