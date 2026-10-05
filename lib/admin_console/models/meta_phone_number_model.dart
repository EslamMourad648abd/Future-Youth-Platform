class MetaPhoneNumberModel {
  final String id;
  final String displayPhoneNumber;
  final String qualityRating;
  final String status;
  final String verifiedName;

  const MetaPhoneNumberModel({
    required this.id,
    required this.displayPhoneNumber,
    required this.qualityRating,
    required this.status,
    required this.verifiedName,
  });

  factory MetaPhoneNumberModel.fromMap(Map<String, dynamic> map) {
    return MetaPhoneNumberModel(
      id: map['id']?.toString() ?? '',
      displayPhoneNumber:
      map['display_phone_number']?.toString() ?? '',
      qualityRating:
      map['quality_rating']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      verifiedName:
      map['verified_name']?.toString() ?? '',
    );
  }
}
