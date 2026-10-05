import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingTaskModel {
  final String id;
  final String task;
  final String taskType;
  final String status;
  final String assignedTo;
  final String createdBy;
  final String clientId;
  final String clientName;
  final String accNumber;
  final String department;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const OnboardingTaskModel({
    required this.id,
    this.task = '',
    required this.taskType,
    required this.status,
    required this.assignedTo,
    required this.createdBy,
    required this.clientId,
    required this.clientName,
    required this.accNumber,
    required this.department,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
  });

  bool get isActive => status == 'In Progress' && finishedAt == null;

  Duration? get completedDuration {
    if (startedAt == null || finishedAt == null) return null;
    return finishedAt!.difference(startedAt!);
  }

  factory OnboardingTaskModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    DateTime? date(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return OnboardingTaskModel(
      id: snapshot.id,
      task: (data['task'] ?? '').toString(),
      taskType: (data['taskType'] ?? '').toString(),
      status: (data['status'] ?? 'In Progress').toString(),
      assignedTo: (data['assignedTo'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      clientId: (data['clientId'] ?? '').toString(),
      clientName: (data['clientName'] ?? '').toString(),
      accNumber: (data['accNumber'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      createdAt: date(data['createdAt']),
      startedAt: date(data['startedAt']),
      finishedAt: date(data['finishedAt']),
    );
  }
}
