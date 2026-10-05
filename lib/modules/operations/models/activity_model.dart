import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String clientId;

  /// Machine-readable event type.
  ///
  /// Examples:
  /// client_created
  /// status_changed
  /// assignment_changed
  /// verification_updated
  /// chatbot_updated
  /// group_updated
  /// crm_updated
  /// note_added
  /// task_created
  /// task_completed
  /// manual
  final String type;

  /// Machine-readable action performed by the actor.
  ///
  /// Examples:
  /// status_changed
  /// assigned
  /// updated
  /// created
  /// completed
  /// deleted
  final String action;

  /// Human-readable activity title.
  final String title;

  /// Human-readable activity description.
  final String description;

  /// Firebase UID of the user who caused the event.
  final String actorId;

  /// Snapshot of the actor's display name at the time of the event.
  ///
  /// Keeping this avoids having old activity entries suddenly change
  /// their displayed name if the user profile changes later.
  final String actorName;

  /// Optional extra information for future reporting/debugging.
  final Map<String, dynamic> metadata;

  final DateTime? createdAt;

  const ActivityModel({
    required this.id,
    required this.clientId,
    required this.type,
    required this.action,
    required this.title,
    required this.description,
    required this.actorId,
    required this.actorName,
    required this.metadata,
    required this.createdAt,
  });

  factory ActivityModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
    final data = snapshot.data() ?? {};

    return ActivityModel(
      id: snapshot.id,
      clientId: (data['clientId'] ?? '').toString(),
      type: (data['type'] ?? 'manual').toString(),
      action: (data['action'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      actorId: (data['actorId'] ?? '').toString(),
      actorName: (data['actorName'] ?? '').toString(),
      metadata: _readMetadata(data['metadata']),
      createdAt: _readDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'type': type,
      'action': action,
      'title': title,
      'description': description,
      'actorId': actorId,
      'actorName': actorName,
      'metadata': metadata,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  static Map<String, dynamic> _readMetadata(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}