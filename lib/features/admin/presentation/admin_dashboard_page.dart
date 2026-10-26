import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool busy = false;

  Future<String?> _rejectionReason(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Reason (required)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text('Reject'),
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
    await _call('reviewTeacher', {
      'teacherId': id,
      'decision': decision,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> _reviewCourse(String id, String decision) async {
    String? reason;
    if (decision == 'reject') {
      reason = await _rejectionReason('Reject course submission');
      if (reason == null) return;
    }
    await _call('reviewCourseContent', {
      'courseId': id,
      'decision': decision,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> _reviewVideo(String courseId, String videoId, String decision) async {
    String? reason;
    if (decision == 'reject') {
      reason = await _rejectionReason('Reject lesson');
      if (reason == null) return;
    }
    await _call('reviewCourseContent', {
      'courseId': courseId,
      'videoId': videoId,
      'decision': decision,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    setState(() => busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable(name).call(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review saved successfully.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Action failed.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
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
          'Payment verification is intentionally disabled for this development stage. '
          'No payment will be confirmed, no subscription will be activated, and no points will be granted.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        
        title: Text('Future Youth • Admin'),
        actions: [
          IconButton(
            tooltip: 'Create admin',
            onPressed: () => context.push(FypRoutes.adminCreateAdmin),
            icon: Icon(Icons.person_add_alt_1),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go(FypRoutes.entry);
            },
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: busy
          ? Center(child: CircularProgressIndicator())
          : ListView(
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
                      Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 34),
                      SizedBox(height: 12),
                      Text(fypTranslate(context, 'platform_control_center', 'Platform control center'), style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        'Review educator applications and course submissions before students can access them.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                const _SectionHeading('Teacher applications', 'Approve educators before they publish courses.'),
                SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users')
                      .where('role', isEqualTo: 'teacher')
                      .where('approvalStatus', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _EmptyMessage('Could not load teacher applications: ${snapshot.error}');
                    if (!snapshot.hasData) return LinearProgressIndicator();
                    if (snapshot.data!.docs.isEmpty) return const _EmptyMessage('No pending teacher applications.');
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data();
                        return _ReviewCard(
                          icon: Icons.school_outlined,
                          title: (data['displayName'] ?? 'Teacher').toString(),
                          subtitle: (data['email'] ?? doc.id).toString(),
                          onApprove: () => _reviewTeacher(doc.id, 'approve'),
                          onReject: () => _reviewTeacher(doc.id, 'reject'),
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: 24),
                const _SectionHeading('Course submissions', 'Review submitted courses before publication.'),
                SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('courses')
                      .where('approvalStatus', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _EmptyMessage('Could not load course submissions: ${snapshot.error}');
                    if (!snapshot.hasData) return LinearProgressIndicator();
                    if (snapshot.data!.docs.isEmpty) return const _EmptyMessage('No pending course submissions.');
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data();
                        return _ReviewCard(
                          icon: Icons.play_lesson_outlined,
                          title: (data['title'] ?? 'Untitled course').toString(),
                          subtitle: '${data['subject'] ?? 'Subject not set'} • Teacher: ${data['teacherId'] ?? 'Unknown'}',
                          onApprove: () => _reviewCourse(doc.id, 'approve'),
                          onReject: () => _reviewCourse(doc.id, 'reject'),
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: 24),
                const _SectionHeading('Lesson submissions', 'Review each lesson before it becomes visible to students.'),
                SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collectionGroup('videos')
                      .where('approvalStatus', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _EmptyMessage('Could not load lesson submissions: ${snapshot.error}');
                    if (!snapshot.hasData) return LinearProgressIndicator();
                    final lessons = snapshot.data!.docs.where((doc) => doc.reference.parent.parent != null).toList();
                    if (lessons.isEmpty) return const _EmptyMessage('No pending lesson submissions.');
                    return Column(
                      children: lessons.map((doc) {
                        final data = doc.data();
                        final courseId = doc.reference.parent.parent!.id;
                        return _ReviewCard(
                          icon: Icons.video_file_outlined,
                          title: (data['title'] ?? 'Untitled lesson').toString(),
                          subtitle: 'Course: $courseId • ${data['durationMinutes'] ?? '—'} min',
                          onApprove: () => _reviewVideo(courseId, doc.id, 'approve'),
                          onReject: () => _reviewVideo(courseId, doc.id, 'reject'),
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: 24),
                const _SectionHeading('Payments', 'Visual preview only — payment processing is disabled.'),
                SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: Colors.white,
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
                            SizedBox(width: 12),
                            Expanded(child: Text(fypTranslate(context, 'payment_verification_workspace', 'Payment verification workspace'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            Chip(label: Text('Preview')),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('The final verification workflow will be connected later. This control does not confirm transfers or grant access.'),
                        SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showPaymentUiOnly,
                          icon: Icon(Icons.visibility_outlined),
                          label: Text('View payment workflow notice'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push(FypRoutes.adminCreateAdmin),
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  label: Text('Create administrator'),
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
          SizedBox(height: 4),
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
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: onReject, child: Text('Reject'))),
                  SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: BrandColors.green),
                      onPressed: onApprove,
                      child: Text('Approve'),
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
