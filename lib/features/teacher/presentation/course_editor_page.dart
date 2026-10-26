import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';

class CourseEditorPage extends StatefulWidget {
  const CourseEditorPage({super.key, required this.courseId});
  final String courseId;
  @override
  State<CourseEditorPage> createState() => _CourseEditorPageState();
}

class _CourseEditorPageState extends State<CourseEditorPage> {
  bool saving = false;

  Future<void> _addLesson() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();
    final input = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add lesson'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Lesson title'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a lesson title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                  validator: (value) {
                    final duration = int.tryParse(value ?? '');
                    return duration == null || duration < 1 ? 'Enter a valid duration' : null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Video upload is not connected yet. This creates lesson metadata only; it does not publish a playable video.',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'duration': durationController.text.trim(),
              });
            },
            child: const Text('Add lesson'),
          ),
        ],
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    if (input == null || !mounted) return;

    setState(() => saving = true);
    try {
      final courseRef = FirebaseFirestore.instance.collection('courses').doc(widget.courseId);
      final courseSnap = await courseRef.get();
      final course = courseSnap.data();
      final user = FirebaseAuth.instance.currentUser;
      if (!courseSnap.exists || course == null || course['teacherId'] != user?.uid || course['status'] != 'draft') {
        throw StateError('Only the owner of a draft course can add lessons.');
      }
      final videos = await courseRef.collection('videos').get();
      final order = videos.docs.length + 1;
      await courseRef.collection('videos').add({
        'teacherId': user!.uid,
        'title': input['title'],
        'description': input['description'],
        'durationMinutes': int.parse(input['duration']!),
        'order': order,
        'status': 'draft',
        'approvalStatus': 'pending',
        'viewCount': 0,
        'ratingCount': 0,
        'ratingSum': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await courseRef.update({
        'lessonCount': order,
        'videoCount': order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson details saved. Add the video file in the next upload stage.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add lesson: ${error.toString().replaceFirst('Bad state: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _addVideoSource(String videoId) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link Google Drive video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Google Drive share URL', hintText: 'https://drive.google.com/file/d/...'),
            ),
            const SizedBox(height: 10),
            const Text(
              'For this prototype, set the Drive file to Anyone with the link can view. Only approved first lessons are shown as student previews.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(dialogContext, controller.text.trim()); }, child: const Text('Save link')),
        ],
      ),
    );
    controller.dispose();
    if (url == null || !mounted) return;
    setState(() => saving = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('registerVideoSource').call({
        'courseId': widget.courseId,
        'videoId': videoId,
        'videoUrl': url,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video source linked. It will be available after lesson and course approval.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Could not link video.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not link video: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final courseRef = FirebaseFirestore.instance.collection('courses').doc(widget.courseId);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Course editor'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : _addLesson,
        backgroundColor: BrandColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add lesson'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: courseRef.snapshots(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) return Center(child: Text('Could not load course: ${courseSnapshot.error}'));
          if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final course = courseSnapshot.data!.data();
          if (course == null) return const Center(child: Text('Course not found.'));
          if (course['teacherId'] != uid) return const Center(child: Text('You can only edit your own courses.'));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [BrandColors.navy, Color(0xFF3D56A6)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.edit_note, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  Text((course['title'] ?? 'Course').toString(), style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${course['subject'] ?? 'Subject'} • ${course['price'] ?? '—'} EGP/month', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Text('Status: ${course['status'] ?? 'draft'} • Review: ${course['approvalStatus'] ?? 'pending'}', style: const TextStyle(color: Colors.white)),
                ]),
              ),
              const SizedBox(height: 20),
              const Text('Lessons', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: BrandColors.navy)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: courseRef.collection('videos').orderBy('order').snapshots(),
                builder: (context, lessonSnapshot) {
                  if (lessonSnapshot.hasError) return Text('Could not load lessons: ${lessonSnapshot.error}');
                  if (!lessonSnapshot.hasData) return const LinearProgressIndicator();
                  final lessons = lessonSnapshot.data!.docs;
                  if (lessons.isEmpty) {
                    return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No lessons yet. Use Add lesson to build the course outline.')));
                  }
                  return Column(
                    children: lessons.map((doc) {
                      final data = doc.data();
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: const Color(0xFFEAF0FF), child: Text('${data['order'] ?? '•'}')),
                          title: Text((data['title'] ?? 'Lesson').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${data['durationMinutes'] ?? '—'} min • ${data['sourceLinked'] == true ? 'Video linked' : 'Video not linked'} • ${data['approvalStatus'] ?? 'pending review'}'),
                          trailing: IconButton(
                            tooltip: 'Link video source',
                            icon: const Icon(Icons.video_file_outlined, color: BrandColors.navy),
                            onPressed: saving ? null : () => _addVideoSource(doc.id),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 70),
            ],
          );
        },
      ),
    );
  }
}
