import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';
import '../../../widgets/app_header_actions.dart';

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
        title: Text(fypTranslate(dialogContext, 'add_lesson', 'Add lesson')),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: fypTranslate(dialogContext, 'lesson_title', 'Lesson title')),
                  validator: (value) => value == null || value.trim().isEmpty ? fypTranslate(dialogContext, 'lesson_title_required', 'Enter a lesson title') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: fypTranslate(dialogContext, 'lesson_description', 'Description')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: fypTranslate(dialogContext, 'duration_minutes', 'Duration (minutes)')),
                  validator: (value) {
                    final duration = int.tryParse(value ?? '');
                    return duration == null || duration < 1 ? fypTranslate(dialogContext, 'enter_valid_duration', 'Enter a valid duration') : null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload a video file (up to 500 MB). The video stays private until approval.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(fypTranslate(dialogContext, 'cancel_action', 'Cancel'))),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'duration': durationController.text.trim(),
              });
            },
            child: Text(fypTranslate(dialogContext, 'add_lesson', 'Add lesson')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fypTranslate(context, 'lesson_saved_upload_video', 'Lesson details saved. Upload its video using the video button.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fypTranslate(context, 'lesson_add_failed', 'Could not add lesson')}: ${error.toString().replaceFirst('Bad state: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _addVideoSource(String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fypTranslate(context, 'upload_read_error', 'Could not read the selected video file. Please try again.'))),
      );
      return;
    }
    if (bytes.length > 500 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fypTranslate(context, 'video_size_limit', 'Videos must be 500 MB or smaller.'))),
      );
      return;
    }

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = 'course-videos/${widget.courseId}/$videoId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    setState(() => saving = true);
    try {
      final task = await FirebaseStorage.instance.ref(storagePath).putData(
        bytes,
        SettableMetadata(contentType: _videoContentType(file.extension)),
      );
      if (task.state != TaskState.success) {
        throw StateError('Video upload did not complete.');
      }
      await FirebaseFunctions.instance.httpsCallable('registerVideoSource').call({
        'courseId': widget.courseId,
        'videoId': videoId,
        'storagePath': storagePath,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fypTranslate(context, 'video_upload_success', 'Video uploaded to private storage. It becomes available after lesson and course approval.'))),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      try { await FirebaseStorage.instance.ref(storagePath).delete(); } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not register the uploaded video.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final messagePrefix = fypTranslate(context, 'upload_failed', 'Could not upload video');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$messagePrefix: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _videoContentType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'mp4': return 'video/mp4';
      case 'webm': return 'video/webm';
      case 'mov': return 'video/quicktime';
      case 'm4v': return 'video/x-m4v';
      case 'avi': return 'video/x-msvideo';
      case 'mpeg':
      case 'mpg': return 'video/mpeg';
      default: return 'video/mp4';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final courseRef = FirebaseFirestore.instance.collection('courses').doc(widget.courseId);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(fypTranslate(context, 'course_editor', 'Course editor')),
        actions: const [AppHeaderActions()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : _addLesson,
        backgroundColor: BrandColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(fypTranslate(context, 'add_lesson', 'Add lesson')),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: courseRef.snapshots(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) return Center(child: Text('${fypTranslate(context, 'course_load_failed', 'Could not load course')}: ${courseSnapshot.error}'));
          if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final course = courseSnapshot.data!.data();
          if (course == null) return Center(child: Text(fypTranslate(context, 'course_not_found', 'Course not found.')));
          if (course['teacherId'] != uid) return Center(child: Text(fypTranslate(context, 'course_owner_only', 'You can only edit your own courses.')));
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
                  Row(
                    children: [
                      const Icon(Icons.edit_note, color: Colors.white, size: 32),
                        icon: const Icon(Icons.folder_shared, size: 18),
                        label: const Text('Sync Drive Playlist'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text((course['title'] ?? fypTranslate(context, 'course_label', 'Course')).toString(), style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${course['subject'] ?? fypTranslate(context, 'subject_label', 'Subject')} • ${AppLocalizations.of(context)?.translate('egp_per_month', params: {'price': '${course['price'] ?? '—'}'}) ?? '${course['price'] ?? '—'} EGP/month'}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Text('${fypTranslate(context, 'status_label', 'Status')}: ${AppLocalizations.of(context)?.translateStatus((course['status'] ?? 'draft').toString()) ?? (course['status'] ?? 'draft')} • ${fypTranslate(context, 'review_label', 'Review')}: ${AppLocalizations.of(context)?.translateStatus((course['approvalStatus'] ?? 'pending').toString()) ?? (course['approvalStatus'] ?? 'pending')}', style: const TextStyle(color: Colors.white)),
                ]),
              ),
              const SizedBox(height: 20),
              Text(fypTranslate(context, 'lessons', 'Lessons'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: courseRef.collection('videos').orderBy('order').snapshots(),
                builder: (context, lessonSnapshot) {
                  if (lessonSnapshot.hasError) return Text('${fypTranslate(context, 'lessons_load_failed', 'Could not load lessons')}: ${lessonSnapshot.error}');
                  if (!lessonSnapshot.hasData) return const LinearProgressIndicator();
                  final lessons = lessonSnapshot.data!.docs;
                  if (lessons.isEmpty) {
                    return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text(fypTranslate(context, 'no_lessons', 'No lessons yet. Use Add lesson to build the course lessons.'))));
                  }
                  return Column(
                    children: lessons.map((doc) {
                      final data = doc.data();
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('${data['order'] ?? '•'}')),
                          title: Text((data['title'] ?? 'Lesson').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${data['durationMinutes'] ?? '—'} min • ${data['sourceLinked'] == true ? fypTranslate(context, 'video_linked', 'Video linked') : fypTranslate(context, 'video_not_linked', 'Video not linked')} • ${AppLocalizations.of(context)?.translateStatus((data['approvalStatus'] ?? 'pending review').toString()) ?? (data['approvalStatus'] ?? 'pending review')}'),
                          trailing: IconButton(
                            tooltip: fypTranslate(context, 'upload_video', 'Upload video'),
                            icon: Icon(data['sourceLinked'] == true ? Icons.check_circle_outline : Icons.upload_file_outlined, color: Theme.of(context).colorScheme.primary),
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
