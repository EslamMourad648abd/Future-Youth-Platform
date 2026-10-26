import 'package:cloud_firestore/cloud_firestore.dart';
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
  int likesCount = 0;
  int dislikesCount = 0;
  bool userLiked = false;
  bool userDisliked = false;

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
        locked = ((data['order'] as num?)?.toInt() ?? 1) > 1 || data['status'] != 'published' || data['approvalStatus'] != 'approved';
        description = data['description'] ?? '';
        videoUrl = data['videoUrl']?.toString();
        likesCount = data['likesCount'] ?? 0;
        dislikesCount = data['dislikesCount'] ?? 0;
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
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
      });
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      if (userLiked) {
        userLiked = false;
        likesCount--;
      } else {
        userLiked = true;
        likesCount++;
        if (userDisliked) {
          userDisliked = false;
          dislikesCount--;
        }
      }
    });

    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .set({
        'likesCount': likesCount,
        'dislikesCount': dislikesCount,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating like: $e');
    }
  }

  Future<void> _toggleDislike() async {
    setState(() {
      if (userDisliked) {
        userDisliked = false;
        dislikesCount--;
      } else {
        userDisliked = true;
        dislikesCount++;
        if (userLiked) {
          userLiked = false;
          likesCount--;
        }
      }
    });

    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .set({
        'likesCount': likesCount,
        'dislikesCount': dislikesCount,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating dislike: $e');
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? 'Student';

    _commentCtrl.clear();

    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'studentId': user?.uid,
        'authorName': userName,
        'comment': text,
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
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BrandColors.navy),
                              ),
                              if (description.isNotEmpty)
                                Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                userLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                color: userLiked ? BrandColors.greenText : Colors.grey,
                              ),
                              onPressed: _toggleLike,
                            ),
                            Text('$likesCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(
                                userDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                                color: userDisliked ? BrandColors.error : Colors.grey,
                              ),
                              onPressed: _toggleDislike,
                            ),
                            Text('$dislikesCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
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
                            backgroundColor: BrandColors.navy,
                            foregroundColor: Colors.white,
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
                                  c['authorName'] ?? 'Student',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BrandColors.navy),
                                ),
                                const SizedBox(height: 4),
                                Text(c['comment'] ?? '', style: const TextStyle(fontSize: 14)),
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
