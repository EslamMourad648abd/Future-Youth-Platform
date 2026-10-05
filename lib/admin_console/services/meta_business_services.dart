import 'package:cloud_functions/cloud_functions.dart';

import '../models/meta_waba_model.dart';

class MetaBusinessService {
  final FirebaseFunctions functions;

  MetaBusinessService({
    required this.functions,
  });

  Future<MetaWabaSnapshot> loadStoredAccounts() async {
    final callable = functions.httpsCallable(
      'getStoredClientWhatsAppBusinessAccounts',
    );

    final result = await callable.call();

    return MetaWabaSnapshot.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<MetaWabaSnapshot> syncAccounts() async {
    final callable = functions.httpsCallable(
      'syncClientWhatsAppBusinessAccounts',
      options: HttpsCallableOptions(
        timeout: const Duration(minutes: 15),
      ),
    );

    final result = await callable.call();

    return MetaWabaSnapshot.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}
