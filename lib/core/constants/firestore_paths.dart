/// Firestore collection names for the Future Youth Platform.
///
/// Keep this file in sync with docs/ARCHITECTURE.md ("Data model") and with
/// the security rules. Never build collection names inline in widgets.
abstract final class FirestorePaths {
  static const String users = 'users';
  static const String courses = 'courses';

  /// Sub-collections of `courses/{courseId}`.
  static const String videos = 'videos';

  /// Server-only sub-collection that holds private storage paths.
  static const String videoSources = 'video_sources';

  /// Sub-collections of `courses/{courseId}/videos/{videoId}`.
  static const String comments = 'comments';
  static const String ratings = 'ratings';

  static const String subscriptions = 'subscriptions';
  static const String payments = 'payments';
  static const String pointsLedger = 'points_ledger';
  static const String videoViews = 'video_views';
}
