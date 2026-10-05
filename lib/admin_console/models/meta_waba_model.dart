import 'meta_phone_number_model.dart';

class MetaWabaModel {
  final String id;
  final String name;
  final String messagingLimit;
  final List<MetaPhoneNumberModel> phoneNumbers;

  const MetaWabaModel({
    required this.id,
    required this.name,
    required this.messagingLimit,
    required this.phoneNumbers,
  });

  factory MetaWabaModel.fromMap(Map<String, dynamic> map) {
    final phones = map['phone_numbers'];

    return MetaWabaModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      messagingLimit:
      map['whatsapp_business_manager_messaging_limit']
          ?.toString() ??
          '',
      phoneNumbers: phones is List
          ? phones
          .whereType<Map>()
          .map(
            (phone) => MetaPhoneNumberModel.fromMap(
          Map<String, dynamic>.from(phone),
        ),
      )
          .toList()
          : const [],
    );
  }
}

class MetaWabaSnapshot {
  final int totalAccounts;
  final int totalPhoneNumbers;
  final String? updatedAt;
  final List<MetaWabaModel> accounts;

  const MetaWabaSnapshot({
    required this.totalAccounts,
    required this.totalPhoneNumbers,
    required this.updatedAt,
    required this.accounts,
  });

  factory MetaWabaSnapshot.fromMap(Map<String, dynamic> map) {
    final accounts = map['accounts'];

    return MetaWabaSnapshot(
      totalAccounts:
      (map['totalAccounts'] as num?)?.toInt() ?? 0,
      totalPhoneNumbers:
      (map['totalPhoneNumbers'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt']?.toString(),
      accounts: accounts is List
          ? accounts
          .whereType<Map>()
          .map(
            (account) => MetaWabaModel.fromMap(
          Map<String, dynamic>.from(account),
        ),
      )
          .toList()
          : const [],
    );
  }
}
