import '../../../core/constants/user_role.dart';
import '../../points/domain/points_policy.dart';

/// Why someone can or cannot watch a video right now.
enum VideoAccess {
  /// Playback may start.
  allowed,

  /// There is no active subscription for the student: show the locked screen.
  /// For a parent this means "subscribe a student to unlock this video".
  paymentRequired,

  /// Subscribed, but the student has no points left.
  noPoints,
}

/// Decides access for the UI. The same decision is made again on the server
/// before a playback URL is issued; the server decision is the one that counts.
///
/// Rules (docs/REQUIREMENTS.md):
/// - FR-05 / D-1: the first video of a course is free for the student so they
///   can assess the teacher before the parent subscribes.
/// - FR-10: any other video is blocked until the parent has paid.
/// - FR-06: paid videos need at least one point.
/// - Teachers and admins are never blocked (they review their own content).
VideoAccess decideVideoAccess({
  required UserRole viewerRole,
  required bool isFreeVideo,
  required bool subscriptionActive,
  required int pointsBalance,
}) {
  switch (viewerRole) {
    case UserRole.teacher:
    case UserRole.admin:
      return VideoAccess.allowed;
    case UserRole.parent:
      return isFreeVideo ? VideoAccess.allowed : VideoAccess.paymentRequired;
    case UserRole.student:
      if (isFreeVideo) return VideoAccess.allowed;
      if (!subscriptionActive) return VideoAccess.paymentRequired;
      if (!PointsPolicy.canAfford(pointsBalance)) return VideoAccess.noPoints;
      return VideoAccess.allowed;
  }
}
