import 'package:cloud_firestore/cloud_firestore.dart';

import 'channel_model.dart';

class ClientModel {
  final String id;

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  final String companyName;
  final String accNumber;
  final String systemType;

  // ============================================================
  // OPERATIONAL STATUS
  // ============================================================

  final String activationStatus;
  final String verificationStatus;
  final String chatbotStatus;
  final String groupStatus;

  // ============================================================
  // OWNERSHIP
  // ============================================================

  final String createdBy;
  final String assignedTo;

  // ============================================================
  // GROUP
  // ============================================================

  final DateTime? groupOpenedAt;
  final DateTime? groupClosedAt;

  // ============================================================
  // INTEGRATION DETAILS
  // ============================================================

  final String bmId;
  final String wabaId;
  final String phoneNumberId;
  final String phoneNumber;

  // ============================================================
  // EXTRA TRACKING
  // ============================================================

  final DateTime? activationDate;
  final int? groupDurationDays;
  final DateTime? verificationDate;
  final String verificationTicketNumber;
  final String months;

  // ============================================================
  // CRM
  // ============================================================

  final String crmComment;

  // ============================================================
  // CHECKLISTS
  // ============================================================

  final Map<String, bool> verificationChecklist;
  final Map<String, bool> chatbotChecklist;

  // ============================================================
  // CHANNELS
  // ============================================================

  final List<ChannelModel> channels;

  // ============================================================
  // TIMESTAMPS
  // ============================================================

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientModel({
    required this.id,
    required this.companyName,
    required this.accNumber,
    required this.systemType,
    required this.activationStatus,
    required this.verificationStatus,
    required this.chatbotStatus,
    required this.groupStatus,
    required this.createdBy,
    required this.assignedTo,

    this.groupOpenedAt,
    this.groupClosedAt,

    this.bmId = '',
    this.wabaId = '',
    this.phoneNumberId = '',
    this.phoneNumber = '',

    this.activationDate,
    this.groupDurationDays,
    this.verificationDate,
    this.verificationTicketNumber = '',
    this.months = '',

    this.crmComment = '',

    this.verificationChecklist = const {},
    this.chatbotChecklist = const {},

    this.channels = const [],

    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // FIRESTORE -> MODEL
  // ============================================================

  factory ClientModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
    final data = snapshot.data() ?? {};

    return ClientModel.fromMap(
      snapshot.id,
      data,
    );
  }

  // ============================================================
  // MAP -> MODEL
  // ============================================================

  factory ClientModel.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    final rawChannels =
        map['channels'] as List<dynamic>? ?? [];

    return ClientModel(
      id: id,

      // ----------------------------------------------------------
      // BASIC
      // ----------------------------------------------------------

      companyName:
      map['companyName']?.toString() ?? '',

      accNumber:
      map['accNumber']?.toString() ?? '',

      systemType:
      map['systemType']?.toString() ?? 'Old',

      // ----------------------------------------------------------
      // STATUS
      // ----------------------------------------------------------

      activationStatus:
      map['activationStatus']?.toString() ??
          'Not Started',

      verificationStatus:
      map['verificationStatus']?.toString() ??
          'Not Started',

      chatbotStatus:
      map['chatbotStatus']?.toString() ??
          'Not Started',

      groupStatus:
      map['groupStatus']?.toString() ??
          'Not Started',

      // ----------------------------------------------------------
      // OWNERSHIP
      // ----------------------------------------------------------

      createdBy:
      map['createdBy']?.toString() ?? '',

      assignedTo:
      map['assignedTo']?.toString() ?? '',

      // ----------------------------------------------------------
      // GROUP
      // ----------------------------------------------------------

      groupOpenedAt:
      _timestampToDate(
        map['groupOpenedAt'],
      ),

      groupClosedAt:
      _timestampToDate(
        map['groupClosedAt'],
      ),

      // ----------------------------------------------------------
      // INTEGRATION
      // ----------------------------------------------------------

      bmId:
      map['bmId']?.toString() ?? '',

      wabaId:
      map['wabaId']?.toString() ?? '',

      phoneNumberId:
      map['phoneNumberId']?.toString() ?? '',

      phoneNumber:
      map['phoneNumber']?.toString() ?? '',

      // ----------------------------------------------------------
      // EXTRA TRACKING
      // ----------------------------------------------------------

      activationDate:
      _timestampToDate(map['activationDate']),

      groupDurationDays:
      map['groupDurationDays'] is int ? map['groupDurationDays'] : int.tryParse(map['groupDurationDays']?.toString() ?? ''),

      verificationDate:
      _timestampToDate(map['verificationDate']),

      verificationTicketNumber:
      map['verificationTicketNumber']?.toString() ?? '',

      months:
      map['months']?.toString() ?? '',

      // ----------------------------------------------------------
      // CRM
      // ----------------------------------------------------------

      crmComment:
      map['crmComment']?.toString() ?? '',

      // ----------------------------------------------------------
      // CHECKLISTS
      // ----------------------------------------------------------

      verificationChecklist:
      _boolMap(
        map['verificationChecklist'],
      ),

      chatbotChecklist:
      _boolMap(
        map['chatbotChecklist'],
      ),

      // ----------------------------------------------------------
      // CHANNELS
      // ----------------------------------------------------------

      channels:
      rawChannels
          .whereType<Map>()
          .map(
            (channel) {
          final channelMap =
          Map<String, dynamic>.from(
            channel,
          );

          return ChannelModel.fromMap(
            channelMap['id']?.toString() ?? '',
            channelMap,
          );
        },
      )
          .toList(),

      // ----------------------------------------------------------
      // TIMESTAMPS
      // ----------------------------------------------------------

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
  // MODEL -> FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'companyName': companyName,
      'accNumber': accNumber,
      'systemType': systemType,

      'activationStatus':
      activationStatus,

      'verificationStatus':
      verificationStatus,

      'chatbotStatus':
      chatbotStatus,

      'groupStatus':
      groupStatus,

      'createdBy':
      createdBy,

      'assignedTo':
      assignedTo,

      'groupOpenedAt':
      groupOpenedAt,

      'groupClosedAt':
      groupClosedAt,

      // ----------------------------------------------------------
      // INTEGRATION
      // ----------------------------------------------------------

      'bmId':
      bmId,

      'wabaId':
      wabaId,

      'phoneNumberId':
      phoneNumberId,

      'phoneNumber':
      phoneNumber,

      'activationDate': activationDate,
      'groupDurationDays': groupDurationDays,
      'verificationDate': verificationDate,
      'verificationTicketNumber': verificationTicketNumber,
      'months': months,

      // ----------------------------------------------------------
      // CRM
      // ----------------------------------------------------------

      'crmComment':
      crmComment,

      // ----------------------------------------------------------
      // CHECKLISTS
      // ----------------------------------------------------------

      'verificationChecklist':
      verificationChecklist,

      'chatbotChecklist':
      chatbotChecklist,

      // ----------------------------------------------------------
      // CHANNELS
      // ----------------------------------------------------------

      'channels':
      channels
          .map(
            (channel) => {
          'id': channel.id,
          ...channel.toMap(),
        },
      )
          .toList(),

      'createdAt':
      createdAt,

      'updatedAt':
      updatedAt,
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  ClientModel copyWith({
    String? companyName,
    String? accNumber,
    String? systemType,

    String? activationStatus,
    String? verificationStatus,
    String? chatbotStatus,
    String? groupStatus,

    String? createdBy,
    String? assignedTo,

    DateTime? groupOpenedAt,
    DateTime? groupClosedAt,

    String? bmId,
    String? wabaId,
    String? phoneNumberId,
    String? phoneNumber,

    DateTime? activationDate,
    int? groupDurationDays,
    DateTime? verificationDate,
    String? verificationTicketNumber,
    String? months,

    String? crmComment,

    Map<String, bool>? verificationChecklist,
    Map<String, bool>? chatbotChecklist,

    List<ChannelModel>? channels,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      id: id,

      companyName:
      companyName ?? this.companyName,

      accNumber:
      accNumber ?? this.accNumber,

      systemType:
      systemType ?? this.systemType,

      activationStatus:
      activationStatus ??
          this.activationStatus,

      verificationStatus:
      verificationStatus ??
          this.verificationStatus,

      chatbotStatus:
      chatbotStatus ??
          this.chatbotStatus,

      groupStatus:
      groupStatus ??
          this.groupStatus,

      createdBy:
      createdBy ?? this.createdBy,

      assignedTo:
      assignedTo ?? this.assignedTo,

      groupOpenedAt:
      groupOpenedAt ??
          this.groupOpenedAt,

      groupClosedAt:
      groupClosedAt ??
          this.groupClosedAt,

      bmId:
      bmId ?? this.bmId,

      wabaId:
      wabaId ?? this.wabaId,

      phoneNumberId:
      phoneNumberId ??
          this.phoneNumberId,

      phoneNumber:
      phoneNumber ??
          this.phoneNumber,

      activationDate: activationDate ?? this.activationDate,
      groupDurationDays: groupDurationDays ?? this.groupDurationDays,
      verificationDate: verificationDate ?? this.verificationDate,
      verificationTicketNumber: verificationTicketNumber ?? this.verificationTicketNumber,
      months: months ?? this.months,

      crmComment:
      crmComment ?? this.crmComment,

      verificationChecklist:
      verificationChecklist ??
          this.verificationChecklist,

      chatbotChecklist:
      chatbotChecklist ??
          this.chatbotChecklist,

      channels:
      channels ?? this.channels,

      createdAt:
      createdAt ?? this.createdAt,

      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // REPORTING HELPERS
  // ============================================================

  int get channelCount =>
      channels.length;

  int get totalChannels =>
      channels.length;

  int channelTypeCount(
      String channelType,
      ) {
    return channels
        .where(
          (channel) =>
      channel.channelType ==
          channelType,
    )
        .length;
  }

  bool get groupIsOpen =>
      groupStatus == 'Opened';

  int? get groupAgeDays {
    if (groupOpenedAt == null) {
      return null;
    }

    final end =
        groupClosedAt ?? DateTime.now();

    return end
        .difference(groupOpenedAt!)
        .inDays;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static Map<String, bool> _boolMap(
      dynamic value,
      ) {
    if (value is! Map) {
      return {};
    }

    return value.map(
          (key, value) => MapEntry(
        key.toString(),
        value == true,
      ),
    );
  }

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