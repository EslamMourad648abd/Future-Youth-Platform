/// Pure rules for the points system.
///
/// This is a UI-side convenience only. The balance and every deduction are
/// owned by Cloud Functions (see docs/ARCHITECTURE.md, "Points"); the client
/// must never be trusted to change a balance.
abstract final class PointsPolicy {
  /// Points taken from the student after one completed video view.
  static const int costPerVideoView = 1;

  /// ASSUMPTION A-3 (docs/REQUIREMENTS.md, "Open questions"): a subscription
  /// grants `videoCount x months` points, i.e. one full pass over the course
  /// for each month the parent pays for. Confirm or change this rule.
  static int pointsForSubscription({
    required int videoCount,
    required int months,
  }) {
    if (videoCount < 0 || months < 0) {
      throw ArgumentError('videoCount and months must not be negative.');
    }
    return videoCount * months;
  }

  /// Whether a student with [balance] points can start another video.
  static bool canAfford(int balance) => balance >= costPerVideoView;
}
