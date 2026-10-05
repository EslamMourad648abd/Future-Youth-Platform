import 'package:cloud_functions/cloud_functions.dart';
class CertificateService {
  final FirebaseFunctions functions;
  CertificateService({
    FirebaseFunctions? functions,
  }) : functions = functions ??
      FirebaseFunctions.instanceFor(
        region: 'us-central1',
      );
  // ============================================================
  // GENERATE / GET CERTIFICATE
  // ============================================================
  Future<String> generateCertificate({
    required String courseId,
  }) async {
    final callable =
    functions.httpsCallable('generateCertificate');
    final result = await callable.call({
      'courseId': courseId,
    });
    final data =
    Map<String, dynamic>.from(result.data as Map);
    if (data['success'] != true) {
      throw Exception(
        'Failed to generate certificate.',
      );
    }
    final certificate =
    Map<String, dynamic>.from(
      data['certificate'] as Map,
    );
    final certificateUrl =
    certificate['certificateUrl'];
    if (certificateUrl == null ||
        certificateUrl.toString().trim().isEmpty) {
      throw Exception(
        'Certificate URL was not returned.',
      );
    }
    return certificateUrl.toString();
  }
}