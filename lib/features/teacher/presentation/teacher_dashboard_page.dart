import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';

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
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _createCourse(BuildContext sheetContext) async {
    final user = FirebaseAuth.instance.currentUser;
    final title = _title.text.trim();
    final subject = _subject.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (user == null || title.isEmpty || subject.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title, subject and valid monthly price.')),
      );
      return;
    }
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
        'lessonCount': 1,
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
      if (!mounted) return;
      Navigator.of(sheetContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course draft created. Add lessons before submitting for review.')),
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
              const Text('Create a course', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Course title', prefixIcon: Icon(Icons.menu_book_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.category_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly price (EGP)', prefixIcon: Icon(Icons.payments_outlined))),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => _createCourse(sheetContext),
                  child: Text(_saving ? 'Saving…' : 'Save draft'),
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
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Teacher Studio'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              context.go(FypRoutes.entry);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCourse,
        backgroundColor: const Color(0xFF00A651),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New course'),
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
                      Text('Welcome, ${profile['displayName'] ?? user?.displayName ?? 'Teacher'}',
                        style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        approved ? 'Your educator profile is approved. Build your learning library.' : 'Your profile is awaiting admin approval. Publishing remains locked until approved.',
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Chip(
                        avatar: Icon(approved ? Icons.verified : Icons.hourglass_top, color: Colors.white, size: 18),
                        label: Text(approved ? 'Approved educator' : 'Approval pending'),
                        backgroundColor: Colors.white.withValues(alpha: .15),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Your courses', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: BrandColors.navy)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('courses').where('teacherId', isEqualTo: user?.uid).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Text('Could not load courses: ${snap.error}');
                if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: const Column(children: [
                      Icon(Icons.video_library_outlined, size: 42, color: BrandColors.navy),
                      SizedBox(height: 10),
                      Text('Your teaching library starts here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      SizedBox(height: 6),
                      Text('Create a course draft to start organising your lessons.', textAlign: TextAlign.center),
                    ]),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueGrey.shade100)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.play_lesson, color: BrandColors.navy),
                        ),
                        title: Text((data['title'] ?? 'Untitled course').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${data['subject'] ?? 'Subject'} • ${data['videoCount'] ?? 0} videos • ${data['price'] ?? '—'} EGP/month\n${data['status'] ?? 'draft'} • ${data['approvalStatus'] ?? 'pending review'}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.info_outline),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text((data['title'] ?? 'Course').toString()),
                            content: Text('Course ID: ${doc.id}\n\nCourse editing, video upload, and analytics are not connected yet. This draft is saved in Firestore.'),
                            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
                          ),
                        ),
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
