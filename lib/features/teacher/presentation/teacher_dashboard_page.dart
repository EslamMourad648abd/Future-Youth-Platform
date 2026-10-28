import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/appbar_actions.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});
  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '250');
  final _lessonCount = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    _price.dispose();
    _lessonCount.dispose();
    super.dispose();
  }

  Future<void> _createCourse(BuildContext sheetContext) async {
    final user = FirebaseAuth.instance.currentUser;
    final title = _title.text.trim();
    final subject = _subject.text.trim();
    final price = double.tryParse(_price.text.trim());
    final lessonCount = int.tryParse(_lessonCount.text.trim());
    if (user == null || title.isEmpty || subject.isEmpty || price == null || price <= 0 || lessonCount == null || lessonCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fypTranslate(context, 'enter_course_fields', 'Enter a title, subject and valid monthly price.'))),
      );
      return;
    }
    final nav = Navigator.of(sheetContext);
    setState(() => _saving = true);
    try {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (profile.data()?['approvalStatus'] != 'approved') {
        throw StateError('Your teacher profile must be approved before creating a course.');
      }
      await FirebaseFirestore.instance.collection('courses').add({
        'teacherId': user.uid,
        'teacherName': profile.data()?['displayName'] ?? user.displayName ?? 'Teacher',
        'title': title,
        'subject': subject,
        'description': _description.text.trim(),
        'price': price,
        'lessonCount': lessonCount,
        'videoCount': 0,
        'status': 'draft',
        'approvalStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _title.clear();
      _subject.clear();
      _description.clear();
      _price.text = '250';
      _lessonCount.text = '1';
      nav.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fypTranslate(context, 'course_draft_created', 'Course draft created. Add lessons before submitting for review.'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCreateCourse() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fypTranslate(context, 'create_course_prompt', 'Create a course'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _title, decoration: InputDecoration(labelText: fypTranslate(sheetContext, 'course_title', 'Course title'), prefixIcon: const Icon(Icons.menu_book_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _subject, decoration: InputDecoration(labelText: fypTranslate(sheetContext, 'subject_label', 'Subject'), prefixIcon: const Icon(Icons.category_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _description, maxLines: 3, decoration: InputDecoration(labelText: fypTranslate(sheetContext, 'description_label', 'Description'))),
              const SizedBox(height: 12),
              TextField(controller: _price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: fypTranslate(sheetContext, 'monthly_price_egp', 'Monthly price (EGP)'), prefixIcon: const Icon(Icons.payments_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _lessonCount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: fypTranslate(sheetContext, 'required_lesson_count', 'Required lesson count (school book)'), prefixIcon: const Icon(Icons.format_list_numbered))),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => _createCourse(sheetContext),
                  child: Text(_saving ? fypTranslate(context, 'saving_label', 'Saving…') : fypTranslate(context, 'save_draft', 'Save draft')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(fypTranslate(context, 'teacher_studio', 'Teacher Studio')),
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        actions: [
          const GlobalAppBarActions(iconColor: Colors.white),
          const SizedBox(width: 4),
          IconButton(
            tooltip: fypTranslate(context, 'sign_out', 'Sign out'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              context.go(FypRoutes.entry);
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCourse,
        backgroundColor: const Color(0xFF00A651),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(fypTranslate(context, 'new_course', 'New course')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snap) {
                final profile = snap.data?.data() ?? {};
                final approved = profile['approvalStatus'] == 'approved';
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [BrandColors.navy, Color(0xFF3E58AA)]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_stories, color: Colors.white, size: 32),
                      const SizedBox(height: 12),
                      Text('${fypTranslate(context, 'welcome_teacher', 'Welcome')}, ${profile['displayName'] ?? user?.displayName ?? fypTranslate(context, 'teacher_label', 'Teacher')}',
                        style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        approved ? 'Your educator profile is approved. Build your learning library.' : 'Your profile is awaiting admin approval. Publishing remains locked until approved.',
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(approved ? Icons.verified : Icons.hourglass_top, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              approved ? 'Approved educator' : 'Approval pending',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(fypTranslate(context, 'your_courses', 'Your courses'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('courses').where('teacherId', isEqualTo: user?.uid).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Text('${fypTranslate(context, 'courses_load_failed', 'Could not load courses')}: ${snap.error}');
                if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18)),
                    child: Column(children: [
                      Icon(Icons.video_library_outlined, size: 42, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text(fypTranslate(context, 'teaching_library_empty', 'Your teaching library starts here'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 6),
                      Text(fypTranslate(context, 'course_create_prompt', 'Create a course draft to start organising your lessons.'), textAlign: TextAlign.center),
                    ]),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.play_lesson, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text((data['title'] ?? 'Untitled course').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${data['subject'] ?? fypTranslate(context, 'subject_label', 'Subject')} • ${data['videoCount'] ?? 0} ${fypTranslate(context, 'videos_label', 'videos')} • ${data['price'] ?? '—'} EGP/month\n${AppLocalizations.of(context)?.translateStatus((data['status'] ?? 'draft').toString()) ?? (data['status'] ?? 'draft')} • ${AppLocalizations.of(context)?.translateStatus((data['approvalStatus'] ?? 'pending review').toString()) ?? (data['approvalStatus'] ?? 'pending review')}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: fypTranslate(context, 'course_analytics', 'Course analytics'),
                          onPressed: () => context.go(FypRoutes.teacherCourseAnalyticsFor(doc.id)),
                          icon: Icon(Icons.insights_outlined, color: Theme.of(context).colorScheme.primary),
                        ),
                        onTap: () => context.go(FypRoutes.teacherCourseEditorFor(doc.id)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
