/// Account / content review state. Admins approve teachers and their videos.
enum ApprovalStatus {
  pending,
  approved,
  rejected;

  static ApprovalStatus? tryParse(String? value) {
    for (final status in ApprovalStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }
}
