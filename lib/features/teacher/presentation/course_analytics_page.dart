import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';

class CourseAnalyticsPage extends StatelessWidget {
  const CourseAnalyticsPage({super.key, required this.courseId});
  final String courseId;

  Future<List<_LessonStats>> _loadStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final results = <_LessonStats>[];
    for (final doc in docs) {
      final data = doc.data();
      final ratings = await doc.reference.collection('ratings').get();
      final comments = await doc.reference.collection('comments').get();
      var ratingTotal = 0;
      for (final rating in ratings.docs) {
        ratingTotal += (rating.data()['value'] as num?)?.toInt() ?? 0;
      }
      results.add(_LessonStats(
        id: doc.id,
        title: (data['title'] ?? 'Lesson').toString(),
        views: (data['viewCount'] as num?)?.toInt() ?? 0,
        ratingCount: ratings.docs.length,
        ratingTotal: ratingTotal,
        commentCount: comments.docs.length,
      ));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(fypTranslate(context, 'course_analytics', 'Course analytics'))),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('courses').doc(courseId).snapshots(),
        builder: (context, courseSnap) {
          if (courseSnap.hasError) return Center(child: Text('${fypTranslate(context, 'course_load_failed', 'Could not load course')}: ${courseSnap.error}'));
          if (!courseSnap.hasData) return Center(child: CircularProgressIndicator());
          final course = courseSnap.data!.data();
          if (course == null) return Center(child: Text(fypTranslate(context, 'course_not_found', 'Course not found.')));
          if (course['teacherId'] != uid) return Center(child: Text(fypTranslate(context, 'course_analytics_owner_only', 'You can only view analytics for your own courses.')));
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('courses').doc(courseId).collection('videos').orderBy('order').snapshots(),
            builder: (context, videosSnap) {
              if (videosSnap.hasError) return Center(child: Text('${fypTranslate(context, 'lessons_load_failed', 'Could not load lessons')}: ${videosSnap.error}'));
              if (!videosSnap.hasData) return Center(child: CircularProgressIndicator());
              final docs = videosSnap.data!.docs;
              return FutureBuilder<List<_LessonStats>>(
                future: _loadStats(docs),
                builder: (context, statsSnap) {
                  if (statsSnap.hasError) return Center(child: Text('${fypTranslate(context, 'ratings_load_failed', 'Unable to load ratings and comments')}: ${statsSnap.error}'));
                  if (!statsSnap.hasData) return Center(child: CircularProgressIndicator());
                  final stats = statsSnap.data!;
                  final views = stats.fold<int>(0, (total, item) => total + item.views);
                  final ratingCount = stats.fold<int>(0, (total, item) => total + item.ratingCount);
                  final ratingTotal = stats.fold<int>(0, (total, item) => total + item.ratingTotal);
                  final commentCount = stats.fold<int>(0, (total, item) => total + item.commentCount);
                  final average = ratingCount == 0 ? 0.0 : ratingTotal / ratingCount;
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [BrandColors.navy, Color(0xFF3D56A6)]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((course['title'] ?? fypTranslate(context, 'course_label', 'Course')).toString(), style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('${course['subject'] ?? fypTranslate(context, 'subject_label', 'Subject')} • ${AppLocalizations.of(context)?.translateStatus((course['status'] ?? 'draft').toString()) ?? (course['status'] ?? 'draft')}', style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 18),
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              _Metric(label: fypTranslate(context, 'views', 'Views'), value: '$views', icon: Icons.visibility_outlined),
                              _Metric(label: fypTranslate(context, 'average_rating_short', 'Avg. rating'), value: ratingCount == 0 ? '—' : average.toStringAsFixed(1), icon: Icons.star_outline),
                              _Metric(label: fypTranslate(context, 'ratings', 'Ratings'), value: '$ratingCount', icon: Icons.rate_review_outlined),
                              _Metric(label: fypTranslate(context, 'comments', 'Comments'), value: '$commentCount', icon: Icons.forum_outlined),
                            ]),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(fypTranslate(context, 'lessons', 'Lessons'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      SizedBox(height: 10),
                      if (stats.isEmpty)
                        const _EmptyAnalytics()
                      else
                        ...stats.map((item) {
                          final avg = item.ratingCount == 0 ? 'No ratings' : '${(item.ratingTotal / item.ratingCount).toStringAsFixed(1)} ★ (${item.ratingCount})';
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: Color(0xFFEAF0FF), child: Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary)),
                              title: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${fypTranslate(context, 'views', 'Views')}: ${item.views} • ${fypTranslate(context, 'ratings', 'Rating')}: $avg • ${fypTranslate(context, 'comments', 'Comments')}: ${item.commentCount}'),
                            ),
                          );
                        }),
                      SizedBox(height: 18),
                      Text(fypTranslate(context, 'views_count_note', 'Views count unique students who received authorized playback access. Paid lesson views require an active subscription.'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LessonStats {
  const _LessonStats({required this.id, required this.title, required this.views, required this.ratingCount, required this.ratingTotal, required this.commentCount});
  final String id;
  final String title;
  final int views;
  final int ratingCount;
  final int ratingTotal;
  final int commentCount;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 135,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white70),
      SizedBox(height: 8),
      Text(value, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white70)),
    ]),
  );
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Icon(Icons.insights_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
      SizedBox(height: 8),
      Text(fypTranslate(context, 'no_lesson_analytics', 'No lesson analytics yet.')),
    ]),
  );
}
