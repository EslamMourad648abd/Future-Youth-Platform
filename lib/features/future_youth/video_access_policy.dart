enum VideoAccessStatus {
  allowed,
  authenticationRequired,
  contentPendingApproval,
  paymentRequired,
  teacherSelectionRequired,
  insufficientPoints,
}

class VideoAccessRequest {
  const VideoAccessRequest({
    required this.isAuthenticated,
    required this.isApproved,
    required this.isFreePreview,
    required this.hasActiveSubscription,
    required this.hasConfirmedTeacherSelection,
    required this.availablePoints,
  });

  final bool isAuthenticated;
  final bool isApproved;
  final bool isFreePreview;
  final bool hasActiveSubscription;
  final bool hasConfirmedTeacherSelection;
  final int availablePoints;
}

class VideoAccessPolicy {
  const VideoAccessPolicy._();

  /// Free previews bypass payment, teacher-selection and points checks only.
  /// Authentication and Admin content approval are always required.
  static VideoAccessStatus evaluate(VideoAccessRequest request) {
    if (!request.isAuthenticated) {
      return VideoAccessStatus.authenticationRequired;
    }
    if (!request.isApproved) {
      return VideoAccessStatus.contentPendingApproval;
    }
    if (request.isFreePreview) {
      return VideoAccessStatus.allowed;
    }
    if (!request.hasConfirmedTeacherSelection) {
      return VideoAccessStatus.teacherSelectionRequired;
    }
    if (!request.hasActiveSubscription) {
      return VideoAccessStatus.paymentRequired;
    }
    if (request.availablePoints <= 0) {
      return VideoAccessStatus.insufficientPoints;
    }
    return VideoAccessStatus.allowed;
  }
}
