class CertificateModel {
  final String id;
  final String userId;
  final String courseId;
  final String traineeName;
  final String courseName;
  final DateTime issuedAt;
  final String storagePath;
  final String downloadUrl;

  const CertificateModel({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.traineeName,
    required this.courseName,
    required this.issuedAt,
    required this.storagePath,
    required this.downloadUrl,
  });

  factory CertificateModel.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return CertificateModel(
      id: id,
      userId: data["userId"] ?? "",
      courseId: data["courseId"] ?? "",
      traineeName: data["traineeName"] ?? "",
      courseName: data["courseName"] ?? "",
      issuedAt: data["issuedAt"] is DateTime
          ? data["issuedAt"]
          : (data["issuedAt"] != null
          ? data["issuedAt"].toDate()
          : DateTime.now()),
      storagePath: data["storagePath"] ?? "",
      downloadUrl: data["downloadUrl"] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "userId": userId,
      "courseId": courseId,
      "traineeName": traineeName,
      "courseName": courseName,
      "issuedAt": issuedAt,
      "storagePath": storagePath,
      "downloadUrl": downloadUrl,
    };
  }
}