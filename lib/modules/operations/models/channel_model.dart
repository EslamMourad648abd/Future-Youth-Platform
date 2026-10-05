import 'package:cloud_firestore/cloud_firestore.dart';

class ChannelModel {
  final String id;

  // ============================================================
  // CHANNEL
  // ============================================================

  final String channelType;
  final String name;
  final String status;

  /// WhatsApp-specific channel implementation.
  ///
  /// Possible values:
  /// - WA Business API
  /// - WA Cloud
  /// - WA Business APP
  final String whatsappType;

  // ============================================================
  // GENERIC CHANNEL VALUE
  // ============================================================

  /// Used by non-WhatsApp channels:
  ///
  /// Instagram  -> Instagram account name
  /// Facebook    -> Facebook page name
  /// TikTok      -> TikTok account name
  /// Telegram    -> Telegram bot URL or username
  /// Website     -> Website URL
  ///
  /// For Call Center it may contain the call center
  /// number/name when appropriate.
  final String channelValue;

  // ============================================================
  // WHATSAPP IDENTIFIERS
  // ============================================================

  final String phoneNumber;
  final String phoneNumberId;

  /// Facebook Business / Meta identifier associated
  /// with this channel.
  final String fbmId;

  final String wabaId;

  // ============================================================
  // CALL CENTER
  // ============================================================

  /// Call center number or name.
  final String callCenterValue;

  /// WhatsApp channel used to log calls.
  final String whatsappChannelToLogCalls;

  /// Whether AI call summary is enabled.
  final bool aiCallSummaryEnabled;

  // ============================================================
  // GENERIC EXTERNAL IDENTIFIER
  // ============================================================

  /// Generic external platform identifier.
  final String externalId;

  // ============================================================
  // TIMESTAMPS
  // ============================================================

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChannelModel({
    required this.id,
    required this.channelType,

    this.name = '',
    this.status = 'Active',

    this.whatsappType = '',

    this.channelValue = '',

    this.phoneNumber = '',
    this.phoneNumberId = '',
    this.fbmId = '',
    this.wabaId = '',

    this.callCenterValue = '',
    this.whatsappChannelToLogCalls = '',
    this.aiCallSummaryEnabled = false,

    this.externalId = '',

    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // FIRESTORE -> MODEL
  // ============================================================

  factory ChannelModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
    return ChannelModel.fromMap(
      snapshot.id,
      snapshot.data() ?? {},
    );
  }

  // ============================================================
  // MAP -> MODEL
  // ============================================================

  factory ChannelModel.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return ChannelModel(
      id: id,

      channelType:
      map['channelType']?.toString() ?? '',

      name:
      map['name']?.toString() ?? '',

      status:
      map['status']?.toString() ?? 'Active',

      whatsappType:
      map['whatsappType']?.toString() ?? '',

      channelValue:
      map['channelValue']?.toString() ?? '',

      phoneNumber:
      map['phoneNumber']?.toString() ?? '',

      phoneNumberId:
      map['phoneNumberId']?.toString() ?? '',

      fbmId:
      map['fbmId']?.toString() ?? '',

      wabaId:
      map['wabaId']?.toString() ?? '',

      callCenterValue:
      map['callCenterValue']?.toString() ?? '',

      whatsappChannelToLogCalls:
      map['whatsappChannelToLogCalls']?.toString() ?? '',

      aiCallSummaryEnabled:
      map['aiCallSummaryEnabled'] == true,

      externalId:
      map['externalId']?.toString() ?? '',

      createdAt:
      _timestampToDate(
        map['createdAt'],
      ),

      updatedAt:
      _timestampToDate(
        map['updatedAt'],
      ),
    );
  }

  // ============================================================
  // MODEL -> MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'channelType': channelType,
      'name': name,
      'status': status,

      'whatsappType': whatsappType,

      'channelValue': channelValue,

      'phoneNumber': phoneNumber,
      'phoneNumberId': phoneNumberId,

      'fbmId': fbmId,
      'wabaId': wabaId,

      'callCenterValue': callCenterValue,
      'whatsappChannelToLogCalls':
      whatsappChannelToLogCalls,
      'aiCallSummaryEnabled':
      aiCallSummaryEnabled,

      'externalId': externalId,

      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  // ============================================================
  // BACKWARD COMPATIBILITY
  // ============================================================

  String get type => channelType;

  // ============================================================
  // COPY WITH
  // ============================================================

  ChannelModel copyWith({
    String? id,
    String? channelType,
    String? name,
    String? status,

    String? whatsappType,

    String? channelValue,

    String? phoneNumber,
    String? phoneNumberId,

    String? fbmId,
    String? wabaId,

    String? callCenterValue,
    String? whatsappChannelToLogCalls,
    bool? aiCallSummaryEnabled,

    String? externalId,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChannelModel(
      id: id ?? this.id,

      channelType:
      channelType ?? this.channelType,

      name:
      name ?? this.name,

      status:
      status ?? this.status,

      whatsappType:
      whatsappType ?? this.whatsappType,

      channelValue:
      channelValue ?? this.channelValue,

      phoneNumber:
      phoneNumber ?? this.phoneNumber,

      phoneNumberId:
      phoneNumberId ?? this.phoneNumberId,

      fbmId:
      fbmId ?? this.fbmId,

      wabaId:
      wabaId ?? this.wabaId,

      callCenterValue:
      callCenterValue ?? this.callCenterValue,

      whatsappChannelToLogCalls:
      whatsappChannelToLogCalls ??
          this.whatsappChannelToLogCalls,

      aiCallSummaryEnabled:
      aiCallSummaryEnabled ??
          this.aiCallSummaryEnabled,

      externalId:
      externalId ?? this.externalId,

      createdAt:
      createdAt ?? this.createdAt,

      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static DateTime? _timestampToDate(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}