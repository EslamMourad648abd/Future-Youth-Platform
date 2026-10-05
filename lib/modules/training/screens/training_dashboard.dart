import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../models/course_model.dart';
import '../repositories/firebase_training_repository.dart';
import '../../../services/localization_service.dart';

class TrainingDashboard extends StatefulWidget {
  const TrainingDashboard({super.key});
  @override
  State<TrainingDashboard> createState() => _TrainingDashboardState();
}

class _TrainingDashboardState extends State<TrainingDashboard> {
  final FirebaseTrainingRepository _repository = FirebaseTrainingRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CourseModel>? _courses;
  Map<String, Map<String, dynamic>> _progressMap = {};
  bool _loadingCourses = true, _loadingProgress = true, _refreshing = false;
  String? _errorMessage;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final gen = ++_loadGeneration;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() { _loadingCourses = _loadingProgress = false; _courses = []; _progressMap = {}; });
      return;
    }
    try {
      final courses = await _repository.getCourses();
      if (!mounted || gen != _loadGeneration) return;
      setState(() { _courses = courses; _loadingCourses = false; _loadingProgress = true; _errorMessage = null; });
      final progress = await _loadCoursesProgress(courses: courses, userId: user.uid);
      if (!mounted || gen != _loadGeneration) return;
      setState(() { _progressMap = progress; _loadingProgress = false; });
    } catch (e) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() { _loadingCourses = _loadingProgress = false; _errorMessage = 'Failed: $e'; });
    }
  }

  Future<void> _refreshDashboard() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try { await _loadDashboard(); } finally { if (mounted) setState(() => _refreshing = false); }
  }

  Future<Map<String, Map<String, dynamic>>> _loadCoursesProgress({required List<CourseModel> courses, required String userId}) async {
    if (courses.isEmpty) return {};
    final res = await Future.wait(courses.map((c) async {
      try { return MapEntry(c.id, await _loadSingleCourseProgress(course: c, userId: userId)); }
      catch (e) { return MapEntry(c.id, {'progress': 0.0, 'lessons': 0, 'duration': 0}); }
    }));
    return Map.fromEntries(res);
  }

  Future<Map<String, dynamic>> _loadSingleCourseProgress({required CourseModel course, required String userId}) async {
    final lessons = await _repository.getLessons(course.id);
    final totalDuration = lessons.fold<int>(0, (t, l) => t + l.duration);
    if (lessons.isEmpty) return {'progress': 0.0, 'lessons': 0, 'duration': totalDuration};
    final snap = await _firestore.collection('users').doc(userId).collection('training_progress').doc(course.id).collection('lessons').get(const GetOptions(source: Source.server));
    final Map<String, Map<String, dynamic>> lp = {for (var d in snap.docs) d.id: d.data()};
    double totalP = 0;
    for (final l in lessons) {
      final d = lp[l.id] ?? {};
      if (l.quizEnabled) {
        if (d['completed'] == true) {
          totalP += 1;
        }
        else { if (d['videoCompleted'] == true) totalP += 0.5; if (d['quizSubmitted'] == true) totalP += 0.5; }
      } else { if (d['completed'] == true || d['videoCompleted'] == true) totalP += 1; }
    }
    return {'progress': (totalP / lessons.length) * 100, 'lessons': lessons.length, 'duration': totalDuration};
  }

  int _countCourses({required bool completed}) {
    int c = 0;
    for (final v in _progressMap.values) {
      final p = (v['progress'] ?? 0).toDouble();
      if (completed ? p >= 100 : (p > 0 && p < 100)) c++;
    }
    return c;
  }

  int _totalDuration() { return _progressMap.values.fold(0, (t, v) => t + (v['duration'] as int? ?? 0)); }
  double _overallProgress() {
    if (_courses == null || _courses!.isEmpty) return 0;
    final valid = _courses!.where((c) => _progressMap.containsKey(c.id)).toList();
    if (valid.isEmpty) return 0;
    return valid.fold(0.0, (t, c) => t + (_progressMap[c.id]!['progress'] as double)) / valid.length;
  }

  CourseModel? _getContinueCourse() {
    if (_courses == null) return null;
    CourseModel? cand; double maxP = 0;
    for (final c in _courses!) {
      final p = (_progressMap[c.id]?['progress'] ?? 0).toDouble();
      if (p > 0 && p < 100 && p > maxP) { maxP = p; cand = c; }
    }
    return cand;
  }

  String _formatDuration(int s) {
    if (s <= 0) return '0 min';
    final m = s ~/ 60, h = m ~/ 60, rm = m % 60;
    if (h == 0) return '$rm min';
    return rm == 0 ? '${h}h' : '${h}h ${rm}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingCourses) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    if (_errorMessage != null) return _DashboardError(message: _errorMessage!, onRetry: _loadDashboard);
    final courses = _courses ?? [];
    if (courses.isEmpty) return const _EmptyTrainingState();

    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 28),
                _loadingProgress ? Center(child: Padding(padding: const EdgeInsets.all(100), child: CircularProgressIndicator(color: theme.colorScheme.primary)))
                : _buildDashboardContent(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n?.translate('training_dashboard') ?? 'Training Dashboard', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        Text(l10n?.translate('training_dashboard_desc') ?? 'Track your training progress.', style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      ])),
      IconButton(onPressed: _refreshing ? null : _refreshDashboard, icon: _refreshing ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)) : Icon(Icons.refresh, color: theme.colorScheme.primary)),
    ]);
  }

  Widget _buildDashboardContent(ThemeData theme) {
    final courses = _courses ?? [];
    final comp = _countCourses(completed: true), inP = _countCourses(completed: false);
    final totalD = _totalDuration(), overallP = _overallProgress(), contC = _getContinueCourse();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildStats(courses, comp, inP, totalD, theme),
      const SizedBox(height: 28),
      _buildOverallProgress(overallP, theme),
      const SizedBox(height: 28),
      if (contC != null) _buildContinueLearning(contC, theme)
      else _buildTrainingStatus(courses, comp, theme),
    ]);
  }

  Widget _buildStats(List<CourseModel> courses, int completed, int inProgress, int totalDuration, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final stats = [
      _StatData(l10n?.translate('courses') ?? 'Courses', '${courses.length}', Icons.menu_book),
      _StatData(l10n?.translate('completed') ?? 'Completed', '$completed', Icons.check_circle),
      _StatData(l10n?.translate('in_progress') ?? 'In Progress', '$inProgress', Icons.timelapse),
      _StatData(l10n?.translate('training_time') ?? 'Training Time', _formatDuration(totalDuration), Icons.schedule),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      int cols = constraints.maxWidth < 700 ? 1 : (constraints.maxWidth < 1100 ? 2 : 4);
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: stats.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 18, mainAxisSpacing: 18, childAspectRatio: cols == 1 ? 4.5 : 2.2),
        itemBuilder: (context, index) => _StatCard(data: stats[index], theme: theme),
      );
    });
  }

  Widget _buildOverallProgress(double progress, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(l10n?.translate('overall_progress') ?? 'Overall Progress', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n?.translate('overall_training_progress') ?? 'Overall Training Progress', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            Text(l10n?.translate('overall_progress_desc') ?? 'Your progress across all available training courses.', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ])),
          Text('${progress.round()}%', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ]),
        const SizedBox(height: 22),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress / 100, minHeight: 10, backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), color: theme.colorScheme.primary)),
      ])),
    );
  }

  Widget _buildContinueLearning(CourseModel course, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final data = _progressMap[course.id] ?? {};
    final progress = (data['progress'] ?? 0).toDouble();
    return Card(
      child: Padding(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n?.translate('continue_learning') ?? 'Continue Learning', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Text(l10n?.translate('pick_up_where') ?? 'Pick up where you left off.', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.school_outlined, color: theme.colorScheme.primary, size: 27)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${data['lessons']} lessons • ${_formatDuration(data['duration'] ?? 0)}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: progress / 100, minHeight: 7, backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), color: theme.colorScheme.primary))),
                const SizedBox(width: 10),
                Text('${progress.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ]),
            ])),
            const SizedBox(width: 18),
            ElevatedButton(onPressed: () => context.go(AppRouter.coursePath(course.id)), style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary, elevation: 0), child: Text(l10n?.translate('continue') ?? 'Continue')),
          ]),
        ),
      ])),
    );
  }

  Widget _buildTrainingStatus(List<CourseModel> courses, int completed, ThemeData theme) {
    final allDone = courses.isNotEmpty && completed == courses.length;
    return Card(
      child: Container(width: double.infinity, padding: const EdgeInsets.all(30), child: Column(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(allDone ? Icons.celebration_outlined : Icons.school_outlined, color: theme.colorScheme.primary, size: 29)),
        const SizedBox(height: 16),
        Text(allDone ? 'Training Completed' : 'Ready to Start', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text(allDone ? 'You have completed all available courses.' : 'Your available training courses are ready for you to start.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5)),
      ])),
    );
  }
}

class _StatData { final String title, value; final IconData icon; _StatData(this.title, this.value, this.icon); }
class _StatCard extends StatelessWidget {
  final _StatData data; final ThemeData theme;
  const _StatCard({required this.data, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)), child: Icon(data.icon, color: theme.colorScheme.primary, size: 23)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(data.title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(data.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ])),
      ])),
    );
  }
}

/*
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();
  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
  }
}
*/

class _DashboardError extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _DashboardError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: Card(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
      const SizedBox(height: 18),
      const Text('Unable to load training', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
      const SizedBox(height: 22),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
    ]))));
  }
}

class _EmptyTrainingState extends StatelessWidget {
  const _EmptyTrainingState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: Card(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 70, height: 70, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.07), shape: BoxShape.circle), child: Icon(Icons.menu_book_outlined, size: 34, color: theme.colorScheme.primary)),
      const SizedBox(height: 20),
      const Text('No courses available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text('Training courses will appear here when they become available.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5)),
    ]))));
  }
}
