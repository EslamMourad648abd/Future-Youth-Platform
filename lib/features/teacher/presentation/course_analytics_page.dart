import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_page.dart';

/// What a teacher sees for their own course: video ratings, comments, views.
/// Task T15.
class CourseAnalyticsPage extends StatelessWidget {
  const CourseAnalyticsPage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(title: 'Course analytics', taskId: 'T15');
  }
}
