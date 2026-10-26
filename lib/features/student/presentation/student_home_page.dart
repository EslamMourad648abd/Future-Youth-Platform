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
          .get();

      final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

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

  Future<void> _requestParentInvoice(Map<String, dynamic> course) async {
    final studentUser = FirebaseAuth.instance.currentUser;
    if (studentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(studentUser.uid)
          .get();

      final parentId = userDoc.data()?['parentId'];
      final studentName = userDoc.data()?['displayName'] ?? studentUser.email ?? 'Student';

      if (parentId == null || parentId.toString().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No parent account linked. Please ask your parent to register you.'),
            backgroundColor: BrandColors.error,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('invoices').add({
        'parentId': parentId,
        'studentId': studentUser.uid,
        'studentName': studentName,
        'teacherId': course['teacherId'] ?? '',
        'teacherName': course['teacherName'] ?? 'Teacher',
        'courseId': course['id'],
        'courseTitle': course['title'] ?? 'Course',
        'amount': 250,
        'currency': 'EGP',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice notification sent to your parent for checkout!'),
          backgroundColor: BrandColors.greenText,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request invoice: $e'),
          backgroundColor: BrandColors.error,
        ),
      );
    }
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
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        title: const Text('Student Learning Portal'),
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
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
                        backgroundColor: BrandColors.greenTint,
                        child: Icon(Icons.school, color: BrandColors.greenText, size: 30),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.navy),
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
                        color: BrandColors.navyTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subject.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BrandColors.navy),
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
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BrandColors.greenText),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(teacherName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  course['title'] ?? 'Course Title',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.navy),
                ),
                if ((course['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    course['description'],
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.go('/student/courses/${course['id']}/videos/lesson_1');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('1st Free Video Preview'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _requestParentInvoice(course),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandColors.navy,
                          side: const BorderSide(color: BrandColors.navy),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.receipt, size: 18),
                        label: const Text('Request Enrollment'),
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
