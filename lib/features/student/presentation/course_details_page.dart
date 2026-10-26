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
        icon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary, size: 36),
        title: Text(fypTranslate(dialogContext, 'subscription_required', 'Subscription required')),
        content: Text(
          fypTranslate(dialogContext, 'first_lesson_free', 'The first approved lesson is a free preview. Access to later lessons requires a subscription. Ask your parent to review subscription options.'),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: Text(fypTranslate(dialogContext, 'got_it', 'Got it'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        
        title: Text(fypTranslate(context, 'course_details', 'Course details')),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('courses').doc(courseId).snapshots(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) return Center(child: Text('Could not load course: ${courseSnapshot.error}'));
          if (!courseSnapshot.hasData) return Center(child: CircularProgressIndicator());
          final course = courseSnapshot.data!.data();
          if (course == null || course['status'] != 'published' || course['approvalStatus'] != 'approved') {
            return Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This course is not available yet.')));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BrandColors.navy, Color(0xFF3D56A6)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book_rounded, color: Colors.white, size: 34),
                    SizedBox(height: 14),
                    Text((course['title'] ?? 'Course').toString(), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('${course['subject'] ?? 'General'} • ${course['teacherName'] ?? 'Teacher'}', style: TextStyle(color: Colors.white70)),
                    if ((course['description'] ?? '').toString().isNotEmpty) ...[
                      SizedBox(height: 12),
                      Text(course['description'].toString(), style: TextStyle(color: Colors.white, height: 1.4)),
                    ],
                    SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _Tag(label: '${course['videoCount'] ?? 0} lessons', icon: Icons.video_library_outlined),
                      _Tag(label: '${course['price'] ?? '—'} EGP / month', icon: Icons.payments_outlined),
                      const _Tag(label: 'First lesson free', icon: Icons.play_circle_outline),
                    ]),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text(fypTranslate(context, 'course_lessons', 'Course lessons'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              SizedBox(height: 8),
              Text(fypTranslate(context, 'preview_hint', 'Preview the first approved lesson. Other lessons stay locked until your parent arranges access.'), style: TextStyle(color: Colors.blueGrey, height: 1.4)),
              SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('courses').doc(courseId).collection('videos')
                    .where('status', isEqualTo: 'published')
                    .where('approvalStatus', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, videoSnapshot) {
                  if (videoSnapshot.hasError) return Text('Could not load lessons: ${videoSnapshot.error}');
                  if (!videoSnapshot.hasData) return Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
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
                          title: Text((data['title'] ?? 'Lesson ${index + 1}').toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(preview ? fypTranslate(context, 'free_preview_no_subscription', 'Free preview • No subscription required') : fypTranslate(context, 'locked_subscription_required', 'Locked • Subscription required')),
                          ),
                          trailing: preview
                              ? Icon(Icons.arrow_forward_ios_rounded, size: 16)
                              : Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
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
      SizedBox(width: 6),
      Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _EmptyLessons extends StatelessWidget {
  const _EmptyLessons();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Icon(Icons.video_library_outlined, color: Theme.of(context).colorScheme.primary, size: 38),
      SizedBox(height: 10),
      Text('No approved lessons yet.'),
    ]),
  );
}
