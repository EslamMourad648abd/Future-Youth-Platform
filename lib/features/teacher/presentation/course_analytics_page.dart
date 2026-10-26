import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';

class CourseAnalyticsPage extends StatelessWidget {
  const CourseAnalyticsPage({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(backgroundColor: BrandColors.navy, foregroundColor: Colors.white, title: const Text('Course analytics')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('courses').doc(courseId).snapshots(),
        builder: (context, courseSnap) {
          if (courseSnap.hasError) return Center(child: Text('Unable to load course: ${courseSnap.error}'));
          if (!courseSnap.hasData) return const Center(child: CircularProgressIndicator());
          final course = courseSnap.data!.data();
          if (course == null) return const Center(child: Text('Course not found.'));
          if (course['teacherId'] != uid) return const Center(child: Text('You can only view analytics for your own courses.'));
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('courses').doc(courseId).collection('videos').snapshots(),
            builder: (context, videosSnap) {
              if (videosSnap.hasError) return Center(child: Text('Unable to load lessons: ${videosSnap.error}'));
              if (!videosSnap.hasData) return const Center(child: CircularProgressIndicator());
              final videos = videosSnap.data!.docs;
              final views = videos.fold<int>(0, (sum, d) => sum + ((d.data()['viewCount'] as num?)?.toInt() ?? 0));
              final comments = videos.fold<int>(0, (sum, d) => sum + ((d.data()['commentCount'] as num?)?.toInt() ?? 0));
              final ratingsCount = videos.fold<int>(0, (sum, d) => sum + ((d.data()['ratingCount'] as num?)?.toInt() ?? 0));
              final ratingSum = videos.fold<double>(0, (sum, d) => sum + ((d.data()['ratingSum'] as num?)?.toDouble() ?? 0));
              final average = ratingsCount == 0 ? 0.0 : ratingSum / ratingsCount;
              return ListView(padding: const EdgeInsets.all(20), children: [
                Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [BrandColors.navy, Color(0xFF3D56A6)]), borderRadius: BorderRadius.circular(22)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((course['title'] ?? 'Course').toString(), style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8), Text('${course['subject'] ?? 'Subject'} • ${course['status'] ?? 'draft'}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, children: [
                      _Metric(label: 'Views', value: '$views', icon: Icons.visibility_outlined),
                      _Metric(label: 'Rating', value: ratingsCount == 0 ? '—' : average.toStringAsFixed(1), icon: Icons.star_outline),
                      _Metric(label: 'Ratings', value: '$ratingsCount', icon: Icons.rate_review_outlined),
                      _Metric(label: 'Comments', value: '$comments', icon: Icons.forum_outlined),
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),
                const Text('Lesson performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BrandColors.navy)),
                const SizedBox(height: 10),
                if (videos.isEmpty) const _EmptyAnalytics()
                else ...videos.map((doc) {
                  final d = doc.data();
                  final count = (d['ratingCount'] as num?)?.toInt() ?? 0;
                  final sum = (d['ratingSum'] as num?)?.toDouble() ?? 0;
                  final avg = count == 0 ? 'No ratings' : '${(sum / count).toStringAsFixed(1)} ★ ($count)';
                  return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFEAF0FF), child: Icon(Icons.play_circle_outline, color: BrandColors.navy)),
                    title: Text((d['title'] ?? 'Lesson').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Views: ${d['viewCount'] ?? 0} • Rating: $avg • Comments: ${d['commentCount'] ?? 0}'),
                  ));
                }),
                const SizedBox(height: 18),
                const Text('Note: analytics update when approved playback, rating and comment events are connected to the lesson documents.', style: TextStyle(color: Colors.blueGrey, height: 1.4)),
              ]);
            },
          );
        },
      ),
    );
  }
}
class _Metric extends StatelessWidget {
  final String label, value; final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override Widget build(BuildContext context) => Container(width: 135, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.white70), const SizedBox(height: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.white70))]));
}
class _EmptyAnalytics extends StatelessWidget {
 const _EmptyAnalytics();
 @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.insights_outlined, size: 40, color: BrandColors.navy), SizedBox(height: 8), Text('No lesson analytics yet')]));
}
