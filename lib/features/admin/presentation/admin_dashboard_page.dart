import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/app_header_actions.dart';
import '../../../widgets/embedded_video_player.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool busy = false;

  Future<void> _previewVideoDialog(String courseId, String videoId, String title, Map<String, dynamic> lesson) async {
    final driveUrl = lesson['driveUrl'] ?? lesson['videoUrl'] ?? lesson['driveFolderUrl'];
    final storagePath = lesson['storagePath'];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: BrandColors.navy, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text('Video Preview: $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Lesson: ${lesson['title'] ?? title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Duration: ${lesson['durationMinutes'] ?? '—'} minutes', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                EmbeddedVideoPlayer(
                  courseId: courseId,
                  videoId: videoId,
                  lessonTitle: (lesson['title'] ?? title).toString(),
                  driveUrl: driveUrl?.toString(),
                  videoUrl: lesson['videoUrl']?.toString(),
                  storagePath: storagePath?.toString(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Review video quality, language content, and duration before approving.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close Preview'),
          ),
        ],
      ),
    );
  }

  Future<String?> _rejectionReason(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: fypTranslate(dialogContext, 'reason_required', 'Reason (required)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(fypTranslate(dialogContext, 'cancel_action', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(fypTranslate(context, 'reject_action', 'Reject')),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _reviewTeacher(String id, String decision) async {
    String? reason;
    if (decision == 'reject') {
      reason = await _rejectionReason('Reject teacher application');
      if (reason == null) return;
    }
    
    try {
      await _call('reviewTeacher', {
        'teacherId': id,
        'decision': decision,
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      debugPrint("reviewTeacher function call error: $e");
    }

    try {
      final updateData = <String, dynamic>{
        'approvalStatus': decision == 'approve' ? 'approved' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (decision == 'reject' && reason != null) {
        updateData['rejectionReason'] = reason;
      }
      await FirebaseFirestore.instance.collection('users').doc(id).update(updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teacher status updated to $decision successfully!')),
        );
      }
    } catch (fsErr) {
      debugPrint("Firestore direct review update error: $fsErr");
    }
  }

  Future<void> _reviewCourse(String id, String decision) async {
    String? reason;
    if (decision == 'reject') {
      reason = await _rejectionReason('Reject course submission');
      if (reason == null) return;
    }

    try {
      await _call('reviewCourseContent', {
        'courseId': id,
        'decision': decision,
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      debugPrint("reviewCourse function call error: $e");
    }

    try {
      final updateData = <String, dynamic>{
        'approvalStatus': decision == 'approve' ? 'approved' : 'rejected',
        'status': decision == 'approve' ? 'published' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (decision == 'reject' && reason != null) {
        updateData['rejectionReason'] = reason;
      }
      await FirebaseFirestore.instance.collection('courses').doc(id).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Course status updated to $decision successfully!')),
        );
      }
    } catch (fsErr) {
      debugPrint("Firestore direct course review error: $fsErr");
    }
  }

  Future<void> _reviewVideo(String courseId, String videoId, String decision) async {
    String? reason;
    if (decision == 'reject') {
      reason = await _rejectionReason('Reject lesson');
      if (reason == null) return;
    }

    try {
      await _call('reviewCourseContent', {
        'courseId': courseId,
        'videoId': videoId,
        'decision': decision,
        if (reason != null) 'reason': reason,
      });
    } catch (e) {
      debugPrint("reviewVideo function call error: $e");
    }

    try {
      final updateData = <String, dynamic>{
        'approvalStatus': decision == 'approve' ? 'approved' : 'rejected',
        'status': decision == 'approve' ? 'published' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (decision == 'reject' && reason != null) {
        updateData['rejectionReason'] = reason;
      }
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('videos')
          .doc(videoId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lesson status updated to $decision successfully!')),
        );
      }
    } catch (fsErr) {
      debugPrint("Firestore direct video review error: $fsErr");
    }
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    setState(() => busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable(name).call(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fypTranslate(context, 'review_saved', 'Review saved successfully.'))),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? fypTranslate(context, 'action_failed_prefix', 'Action failed'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fypTranslate(context, 'action_failed_prefix', 'Action failed')}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showPaymentUiOnly() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.construction_outlined, color: Theme.of(context).colorScheme.primary, size: 36),
        title: Text(fypTranslate(dialogContext, 'payment_controls_ui_only', 'Payment controls are UI-only')),
        content: Text(
          fypTranslate(dialogContext, 'payment_full_notice', 'Payment verification is intentionally disabled for this development stage. No payment will be confirmed, no subscription will be activated, and no points will be granted.'),
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
        title: Text(fypTranslate(context, 'future_youth_admin', 'Future Youth • Admin')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.go(FypRoutes.entry),
        ),
        actions: [
          const AppHeaderActions(),
          IconButton(
            tooltip: fypTranslate(context, 'create_admin', 'Create admin'),
            onPressed: () => context.push(FypRoutes.adminCreateAdmin),
            icon: const Icon(Icons.person_add_alt_1),
          ),
          IconButton(
            tooltip: fypTranslate(context, 'sign_out', 'Sign out'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go(FypRoutes.entry);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                      const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 34),
                      const SizedBox(height: 12),
                      Text(fypTranslate(context, 'platform_control_center', 'Platform control center'), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        fypTranslate(context, 'review_educators_courses', 'Review educator applications and course submissions before students can access them.'),
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeading('Teacher applications', 'Approve educators before they publish courses.'),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users')
                      .where('role', isEqualTo: 'teacher')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _EmptyMessage('Could not load teacher applications: ${snapshot.error}');
                    if (!snapshot.hasData) return const LinearProgressIndicator();

                    final pendingTeachers = snapshot.data!.docs.where((doc) {
                      final status = (doc.data()['approvalStatus'] ?? '').toString();
                      return status != 'approved';
                    }).toList();

                    if (pendingTeachers.isEmpty) return const _EmptyMessage('No pending teacher applications.');

                    return Column(
                      children: pendingTeachers.map((doc) {
                        final data = doc.data();
                        return _ReviewCard(
                          icon: Icons.school_outlined,
                          title: (data['displayName'] ?? data['email'] ?? 'Teacher').toString(),
                          subtitle: (data['email'] ?? doc.id).toString(),
                          onApprove: () => _reviewTeacher(doc.id, 'approve'),
                          onReject: () => _reviewTeacher(doc.id, 'reject'),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _SectionHeading('Course Submissions & Lessons', 'Review courses and preview nested lesson videos before publishing.'),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('courses').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _EmptyMessage('Could not load courses: ${snapshot.error}');
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    final courses = snapshot.data!.docs;
                    if (courses.isEmpty) return const _EmptyMessage('No courses submitted for review.');

                    return Column(
                      children: courses.map((cDoc) {
                        final cData = cDoc.data();
                        final courseId = cDoc.id;
                        final courseTitle = cData['title'] ?? 'Course Title';
                        final subject = cData['subject'] ?? 'General';
                        final price = cData['price'] ?? 250;
                        final approvalStatus = cData['approvalStatus'] ?? 'pending';

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: ExpansionTile(
                            leading: Icon(
                              approvalStatus == 'approved' ? Icons.check_circle : Icons.play_lesson_outlined,
                              color: approvalStatus == 'approved' ? BrandColors.green : BrandColors.navy,
                            ),
                            title: Text(courseTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text('$subject • $price EGP/month • Status: $approvalStatus'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _reviewCourse(courseId, 'reject'),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject Course'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: BrandColors.green),
                                      onPressed: () => _reviewCourse(courseId, 'approve'),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve Course'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('courses')
                                    .doc(courseId)
                                    .collection('videos')
                                    .snapshots(),
                                builder: (context, lessonSnap) {
                                  if (!lessonSnap.hasData) return const LinearProgressIndicator();
                                  final lessons = lessonSnap.data!.docs;
                                  if (lessons.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('No lessons added to this course yet.', style: TextStyle(color: Colors.grey)),
                                    );
                                  }

                                  return Column(
                                    children: lessons.map((lDoc) {
                                      final lData = lDoc.data();
                                      final lessonId = lDoc.id;
                                      final lTitle = lData['title'] ?? 'Lesson';
                                      final lStatus = lData['approvalStatus'] ?? 'pending';

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                        leading: const Icon(Icons.video_file, color: BrandColors.navy),
                                        title: Text(lTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: Text('${lData['durationMinutes'] ?? '—'} min • Status: $lStatus'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.play_circle_fill, color: Colors.blue),
                                              tooltip: 'Preview Video',
                                              onPressed: () => _previewVideoDialog(courseId, lessonId, lTitle, lData),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, color: BrandColors.green),
                                              tooltip: 'Approve Lesson',
                                              onPressed: () => _reviewVideo(courseId, lessonId, 'approve'),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel, color: BrandColors.error),
                                              tooltip: 'Reject Lesson',
                                              onPressed: () => _reviewVideo(courseId, lessonId, 'reject'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _SectionHeading('Payments', 'Visual preview only — payment processing is disabled.'),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary, size: 30),
                            const SizedBox(width: 12),
                            Expanded(child: Text(fypTranslate(context, 'payment_verification_workspace', 'Payment verification workspace'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            Chip(label: Text(fypTranslate(context, 'preview_action', 'Preview'))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(fypTranslate(context, 'verification_later_notice', 'The final verification workflow will be connected later. This control does not confirm transfers or grant access.')),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showPaymentUiOnly,
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(fypTranslate(context, 'payment_workflow_notice', 'View payment workflow notice')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push(FypRoutes.adminCreateAdmin),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(fypTranslate(context, 'create_administrator', 'Create administrator')),
                ),
              ],
            ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onApprove,
    required this.onReject,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: onReject, child: Text(fypTranslate(context, 'reject_action', 'Reject')))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: BrandColors.green),
                      onPressed: onApprove,
                      child: Text(fypTranslate(context, 'approve_action', 'Approve')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Text(message),
      );
}
