import 'package:cloud_functions/cloud_functions.dart';

class CrmService {
  CrmService({
    FirebaseFunctions? functions,
  }) : _functions =
      functions ??
          FirebaseFunctions.instanceFor(
            region: 'us-central1',
          );

  final FirebaseFunctions _functions;

  // ============================================================
  // SUBMIT CRM COMMENT
  // ============================================================

  Future<void> submitComment({
    required String accountNumber,
    required String comment,
  }) async {
    final cleanAccount =
    accountNumber.trim();

    final cleanComment =
    comment.trim();

    if (cleanAccount.isEmpty) {
      throw Exception(
        'Account number is required.',
      );
    }

    if (cleanComment.isEmpty) {
      throw Exception(
        'Comment is required.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'updateCrmComment',
    );

    await callable.call({
      'accountNumber':
      cleanAccount,

      'comment':
      cleanComment,
    });
  }
}