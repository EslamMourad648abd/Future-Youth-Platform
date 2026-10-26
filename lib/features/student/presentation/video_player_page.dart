import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../modules/training/widgets/google_drive_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String courseId;
  final String videoId;

  const VideoPlayerPage({
    super.key,
    required this.courseId,
    required this.videoId,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final _commentCtrl = TextEditingController();

  bool loading = true;
  bool locked = false;
  String? loadError;
  String? videoUrl;
  String title = 'Lesson Video';
  String description = '';
  int userRating = 0;
  int ratingCount = 0;
  double ratingAverage = 0;

  List<Map<String, dynamic>> comments = [];

  @override
  void initState() {
    super.initState();
    _loadVideoAndComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVideoAndComments() async {
    try {
      final lessonDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .get();

      if (lessonDoc.exists) {
        final data = lessonDoc.data()!;
        title = data['title'] ?? 'Lesson Video';
        final lessonOrder = (data['order'] as num?)?.toInt() ?? 1;
        locked = data['status'] != 'published' || data['approvalStatus'] != 'approved';
        description = data['description'] ?? '';
        if (!locked) {
          final callableName = lessonOrder == 1
              ? 'getPreviewVideoUrl'
              : 'getPaidLessonVideoUrl';
          final result = await FirebaseFunctions.instance.httpsCallable(callableName).call({
            'courseId': widget.courseId,
            'videoId': widget.videoId,
          });
          videoUrl = (result.data as Map)['videoUrl']?.toString();
          locked = videoUrl == null || videoUrl!.isEmpty;
        }

      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .collection('ratings')
          .get();
      var ratingTotal = 0;
      var myRating = 0;
      for (final ratingDoc in ratingsSnapshot.docs) {
        final value = (ratingDoc.data()['value'] as num?)?.toInt() ?? 0;
        ratingTotal += value;
        if (ratingDoc.id == currentUid) myRating = value;
      }

      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      final commentList = commentsSnapshot.docs.map((doc) => doc.data()).toList();

      if (!mounted) return;
      setState(() {
        comments = commentList;
        ratingCount = ratingsSnapshot.docs.length;
        ratingAverage = ratingCount == 0 ? 0 : ratingTotal / ratingCount;
        userRating = myRating;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        locked = true;
        loadError = e.toString();
      });
    }
  }

  Future<void> _setRating(int value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .collection('ratings')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'value': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        final total = ratingAverage * ratingCount;
        if (userRating == 0) {
          ratingCount++;
          ratingAverage = (total + value) / ratingCount;
        } else {
          ratingAverage = (total - userRating + value) / ratingCount;
        }
        userRating = value;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rating: $e')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    _commentCtrl.clear();

    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'uid': user?.uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadVideoAndComments();
    } catch (e) {
      debugPrint('Error posting comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(FypRoutes.student),
        ),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : locked
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline, size: 52, color: BrandColors.navy),
                              const SizedBox(height: 14),
                              const Text('This lesson is locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: BrandColors.navy)),
                              const SizedBox(height: 8),
                              const Text('Only the first approved lesson is available as a free preview. Ask your parent about subscription options.', textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: () => context.go(FypRoutes.student), child: const Text('Back to courses')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (videoUrl != null && videoUrl!.isNotEmpty)
                      SizedBox(
                        height: 340,
                        child: GoogleDrivePlayer(videoUrl: videoUrl!),
                      )
                    else
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(loadError == null ? 'Video preview is not configured for this lesson yet.' : 'Could not load lesson: $loadError', textAlign: TextAlign.center),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ratingCount == 0 ? 'Be the first to rate this lesson' : '${ratingAverage.toStringAsFixed(1)} / 5 • $ratingCount ratings',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: BrandColors.navy)),
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(5, (index) => IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Rate ${index + 1} stars',
                                    onPressed: () => _setRating(index + 1),
                                    icon: Icon(index < userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: const Color(0xFFFFB300)),
                                  )),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),

                    // ========================================================
                    // COMMENTS SECTION
                    // ========================================================
                    const Text(
                      'Student Comments & Questions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: BrandColors.navy),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment or ask a question...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _postComment,
                          style: ElevatedButton.styleFrom(
                            
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          child: const Icon(Icons.send, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (comments.isEmpty)
                      const Text('No comments yet. Be the first to ask a question!', style: TextStyle(color: Colors.grey))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8EF)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['authorName'] ?? c['uid'] ?? 'Student',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BrandColors.navy),
                                ),
                                const SizedBox(height: 4),
                                Text(c['text'] ?? c['comment'] ?? '', style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
