import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';

class StudentCourseDetailsPage extends StatelessWidget {
  const StudentCourseDetailsPage({super.key, required this.courseId});
  final String courseId;

  Future<void> _showLockedLesson(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: BrandColors.navy, size: 36),
        title: const Text('Subscription required'),
        content: const Text(
          'The first approved lesson is a free preview. Access to later lessons requires a subscription. '
          'Ask your parent to open Parent Workspace to review subscription options. Payment processing is not enabled in this build.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        
        title: const Text('Course details'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('courses').doc(courseId).snapshots(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) return Center(child: Text('Could not load course: ${courseSnapshot.error}'));
          if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final course = courseSnapshot.data!.data();
          if (course == null || course['status'] != 'published' || course['approvalStatus'] != 'approved') {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This course is not available yet.')));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [BrandColors.navy, Color(0xFF3D56A6)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 34),
                    const SizedBox(height: 14),
                    Text((course['title'] ?? 'Course').toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${course['subject'] ?? 'General'} • ${course['teacherName'] ?? 'Teacher'}', style: const TextStyle(color: Colors.white70)),
                    if ((course['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(course['description'].toString(), style: const TextStyle(color: Colors.white, height: 1.4)),
                    ],
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _Tag(label: '${course['videoCount'] ?? 0} lessons', icon: Icons.video_library_outlined),
                      _Tag(label: '${course['price'] ?? '—'} EGP / month', icon: Icons.payments_outlined),
                      const _Tag(label: 'First lesson free', icon: Icons.play_circle_outline),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(fypTranslate(context, 'course_lessons', 'Course lessons'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: BrandColors.navy)),
              const SizedBox(height: 8),
              const Text('Preview the first approved lesson. Other lessons display as locked until your parent arranges access.', style: TextStyle(color: Colors.blueGrey, height: 1.4)),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('courses').doc(courseId).collection('videos')
                    .where('status', isEqualTo: 'published')
                    .where('approvalStatus', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, videoSnapshot) {
                  if (videoSnapshot.hasError) return Text('Could not load lessons: ${videoSnapshot.error}');
                  if (!videoSnapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  final lessons = videoSnapshot.data!.docs.toList()
                    ..sort((a, b) => ((a.data()['order'] as num?)?.toInt() ?? 0)
                        .compareTo((b.data()['order'] as num?)?.toInt() ?? 0));
                  if (lessons.isEmpty) {
                    return const _EmptyLessons();
                  }
                  return Column(
                    children: List.generate(lessons.length, (index) {
                      final lesson = lessons[index];
                      final data = lesson.data();
                      final preview = index == 0;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blueGrey.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: preview ? BrandColors.greenTint : const Color(0xFFE9EDF5),
                            child: Icon(preview ? Icons.play_arrow_rounded : Icons.lock_outline,
                              color: preview ? BrandColors.greenText : BrandColors.navy),
                          ),
                          title: Text((data['title'] ?? 'Lesson ${index + 1}').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(preview ? 'Free preview • No subscription required' : 'Locked • Subscription required'),
                          ),
                          trailing: preview
                              ? const Icon(Icons.arrow_forward_ios_rounded, size: 16)
                              : const Icon(Icons.lock_outline, color: BrandColors.navy),
                          onTap: preview
                              ? () => context.go(FypRoutes.studentVideoFor(courseId, lesson.id))
                              : () => _showLockedLesson(context),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 16),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _EmptyLessons extends StatelessWidget {
  const _EmptyLessons();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
    child: const Column(children: [
      Icon(Icons.video_library_outlined, color: BrandColors.navy, size: 38),
      SizedBox(height: 10),
      Text('No approved lessons yet.'),
    ]),
  );
}
