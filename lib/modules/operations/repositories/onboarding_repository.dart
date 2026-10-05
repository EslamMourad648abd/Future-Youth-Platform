
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/activity_model.dart';
import '../models/channel_model.dart';
import '../models/client_model.dart';
import '../models/onboarding_tasks_model.dart';
import '../../../services/debug_log_service.dart';

class OnboardingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final _log = DebugLogService();

  OnboardingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _clients =>
      _firestore.collection('clients');

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('onboarding_tasks');

  // ============================================================
  // ALL CLIENTS
  // ============================================================

  Stream<List<ClientModel>> watchClients() {
    return _clients.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(ClientModel.fromFirestore).toList(),
    );
  }

  // ============================================================
  // ONE CLIENT
  // ============================================================

  Stream<ClientModel?> watchClient(String clientId) {
    return _clients.doc(clientId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return ClientModel.fromFirestore(snapshot);
    });
  }

  // ============================================================
  // CLIENT ACTIVITY
  // ============================================================

  CollectionReference<Map<String, dynamic>> _activity(String clientId) {
    return _clients.doc(clientId).collection('activity');
  }

  Stream<List<ActivityModel>> watchClientActivity(String clientId) {
    return _activity(clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map(ActivityModel.fromFirestore).toList(),
    );
  }

  Stream<List<ActivityModel>> watchRecentClientActivity(
      String clientId, {
        int limit = 10,
      }) {
    return _activity(clientId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map(ActivityModel.fromFirestore).toList(),
    );
  }

  Future<List<ActivityModel>> getClientActivity(
      String clientId, {
        int limit = 100,
      }) async {
    final snapshot = await _activity(clientId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(ActivityModel.fromFirestore).toList();
  }

  Future<Map<String, dynamic>> _buildActivityData({
    required String clientId,
    required String type,
    required String action,
    required String title,
    String description = '',
    String? actorName,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to create client activity.',
      );
    }

    String resolvedActorName = actorName?.trim() ?? '';

    if (resolvedActorName.isEmpty) {
      try {
        final userSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userSnapshot.data() ?? <String, dynamic>{};

        final username = userData['username']?.toString().trim() ?? '';
        final displayName = userData['displayName']?.toString().trim() ?? '';
        final email = userData['email']?.toString().trim() ?? '';

        if (username.isNotEmpty) {
          resolvedActorName = username;
        } else if (displayName.isNotEmpty) {
          resolvedActorName = displayName;
        } else if (user.displayName?.trim().isNotEmpty == true) {
          resolvedActorName = user.displayName!.trim();
        } else if (email.isNotEmpty) {
          resolvedActorName = email;
        } else if (user.email?.trim().isNotEmpty == true) {
          resolvedActorName = user.email!.trim();
        } else {
          resolvedActorName = user.uid;
        }
      } catch (_) {
        resolvedActorName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email?.trim().isNotEmpty == true
            ? user.email!.trim()
            : user.uid;
      }
    }

    return <String, dynamic>{
      'clientId': clientId,
      'type': type.trim(),
      'action': action.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'actorId': user.uid,
      'actorName': resolvedActorName,
      'metadata': Map<String, dynamic>.from(metadata),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<String> addActivity({
    required String clientId,
    required String type,
    required String action,
    required String title,
    String description = '',
    String? actorName,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final document = _activity(clientId).doc();

    final activityData = await _buildActivityData(
      clientId: clientId,
      type: type,
      action: action,
      title: title,
      description: description,
      actorName: actorName,
      metadata: metadata,
    );

    await document.set(activityData);

    return document.id;
  }

  Future<String> logStatusChange({
    required String clientId,
    required String type,
    required String field,
    required String oldValue,
    required String newValue,
    String? actorName,
  }) {
    return addActivity(
      clientId: clientId,
      type: type,
      action: 'status_changed',
      title: '${_activityTypeLabel(type)} status changed',
      description:
      '${_activityTypeLabel(type)} status changed from "$oldValue" to "$newValue".',
      actorName: actorName,
      metadata: {
        'field': field,
        'oldValue': oldValue,
        'newValue': newValue,
      },
    );
  }

  String _activityTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'channel':
        return 'Channel';
      case 'activation':
        return 'Activation';
      case 'verification':
        return 'Verification';
      case 'chatbot':
        return 'Chatbot';
      case 'group':
        return 'Group';
      case 'assignment':
        return 'Assignment';
      case 'crm':
        return 'CRM';
      case 'task':
        return 'Task';
      case 'client':
        return 'Client';
      default:
        return type.trim().isEmpty ? 'Client' : type.trim();
    }
  }

  // ============================================================
  // CREATE CLIENT
  // ============================================================

  Future<String> createClient({
    required String companyName,
    required String accNumber,
    required String systemType,
    String phoneNumber = '',
    String phoneNumberId = '',
    String bmId = '',
    String wabaId = '',
    String assignedTo = '',
    String crmComment = '',
    DateTime? activationDate,
    int? groupDurationDays,
    DateTime? verificationDate,
    String verificationTicketNumber = '',
    String months = '',
    DateTime? createdAt,
    String? activationStatus,
    String? verificationStatus,
    String? chatbotStatus,
    String? groupStatus,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to create a client.');
    }

    final document = _clients.doc();

    final resolvedAssignedTo =
    assignedTo.trim().isEmpty ? user.uid : assignedTo.trim();

    final now = FieldValue.serverTimestamp();

    await document.set({
      'companyName': companyName.trim(),
      'accNumber': accNumber.trim(),
      'systemType': systemType.trim(),
      'bmId': bmId.trim(),
      'wabaId': wabaId.trim(),
      'phoneNumberId': phoneNumberId.trim(),
      'phoneNumber': phoneNumber.trim(),
      'activationStatus': activationStatus?.trim() ?? 'Not Started',
      'verificationStatus': verificationStatus?.trim() ?? 'Not Started',
      'chatbotStatus': chatbotStatus?.trim() ?? 'Not Started',
      'groupStatus': groupStatus?.trim() ?? 'Not Started',
      'activationDate': activationDate,
      'groupDurationDays': groupDurationDays,
      'verificationDate': verificationDate,
      'verificationTicketNumber': verificationTicketNumber.trim(),
      'months': months.trim(),
      'createdBy': user.uid,
      'assignedTo': resolvedAssignedTo,
      'groupOpenedAt': null,
      'groupClosedAt': null,
      'crmComment': crmComment.trim(),
      'verificationChecklist': <String, bool>{},
      'chatbotChecklist': <String, bool>{},
      'channels': <Map<String, dynamic>>[],
      'createdAt': createdAt ?? now,
      'updatedAt': now,
    });

    return document.id;
  }

  // ============================================================
  // UPDATE CLIENT
  // ============================================================

  Future<void> updateClient(
      ClientModel client,
      Map<String, String> map,
      ) async {
    final data = client.toFirestore();

    data.remove('createdAt');
    data.remove('updatedAt');
    data.remove('createdBy');

    await _clients.doc(client.id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateClientFields(
      String clientId,
      Map<String, dynamic> fields,
      ) async {
    _log.ui('Updating client fields for $clientId: ${fields.keys.join(", ")}');
    if (fields.isEmpty) return;

    final safeFields = Map<String, dynamic>.from(fields);

    safeFields.remove('id');
    safeFields.remove('createdAt');
    safeFields.remove('updatedAt');
    safeFields.remove('createdBy');

    await _clients.doc(clientId).update({
      ...safeFields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAssignedTo(
      String clientId,
      String userId,
      ) async {
    await _clients.doc(clientId).update({
      'assignedTo': userId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCrmComment(
      String clientId,
      String comment,
      ) async {
    _log.ui('Submitting CRM comment for client $clientId: $comment');
    final cleanClientId = clientId.trim();
    final newComment = comment.trim();

    if (cleanClientId.isEmpty) {
      throw Exception('Client ID is required.');
    }

    if (newComment.isEmpty) {
      throw Exception('CRM comment cannot be empty.');
    }

    final clientDocument = _clients.doc(cleanClientId);
    final snapshot = await clientDocument.get();

    if (!snapshot.exists) {
      throw Exception('Client not found.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final oldComment = data['crmComment']?.toString().trim() ?? '';

    // Do not create a duplicate activity when the saved comment did not change.
    if (oldComment == newComment) {
      return;
    }

    final activityDocument = _activity(cleanClientId).doc();
    final activityData = await _buildActivityData(
      clientId: cleanClientId,
      type: 'crm',
      action: 'comment_submitted',
      title: 'CRM comment submitted',
      description: 'A CRM comment was submitted for this client.',
      metadata: {
        'comment': newComment,
        if (oldComment.isNotEmpty) 'previousComment': oldComment,
      },
    );

    // Keep the local client change and its audit event atomic.
    final batch = _firestore.batch();

    batch.update(clientDocument, {
      'crmComment': newComment,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(activityDocument, activityData);

    await batch.commit();
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> updateStatuses({
    required String clientId,
    String? activationStatus,
    String? verificationStatus,
    String? chatbotStatus,
    String? groupStatus,
  }) async {
    _log.ui('Updating client statuses for $clientId: verification=$verificationStatus');
    final fields = <String, dynamic>{};

    if (activationStatus != null) {
      fields['activationStatus'] = activationStatus;
    }

    if (verificationStatus != null) {
      fields['verificationStatus'] = verificationStatus;
    }

    if (chatbotStatus != null) {
      fields['chatbotStatus'] = chatbotStatus;
    }

    if (groupStatus != null) {
      fields['groupStatus'] = groupStatus;
    }

    if (fields.isEmpty) return;

    await _clients.doc(clientId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE INTEGRATION DETAILS
  // ============================================================

  Future<void> updateIntegrationDetails({
    required String clientId,
    String? bmId,
    String? wabaId,
    String? phoneNumberId,
    String? phoneNumber,
  }) async {
    final fields = <String, dynamic>{};

    if (bmId != null) {
      fields['bmId'] = bmId.trim();
    }

    if (wabaId != null) {
      fields['wabaId'] = wabaId.trim();
    }

    if (phoneNumberId != null) {
      fields['phoneNumberId'] = phoneNumberId.trim();
    }

    if (phoneNumber != null) {
      fields['phoneNumber'] = phoneNumber.trim();
    }

    if (fields.isEmpty) return;

    await _clients.doc(clientId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

// ============================================================
// CHANNELS
// ============================================================

  Future<void> addChannel(
      String clientId,
      ChannelModel channel,
      ) async {
    final cleanClientId = clientId.trim();

    if (cleanClientId.isEmpty) {
      throw Exception('Client ID is required.');
    }

    final clientDocument = _clients.doc(cleanClientId);
    final activityDocument = _activity(cleanClientId).doc();

    final channelData = <String, dynamic>{
      'id': channel.id,
      ...channel.toMap(),
    };

    final activityData = await _buildActivityData(
      clientId: cleanClientId,
      type: 'channel',
      action: 'created',
      title: 'Channel added',
      description: _channelActivityDescription(
        channel,
        action: 'added',
      ),
      metadata: {
        'channelName': _channelDisplayName(channel),
        'channelType': channel.channelType,
        'status': channel.status,
        'channelId': channel.id,
        'channel': _channelActivityMetadata(channel),
      },
    );

    // Save the channel and its audit event together.
    // If either write fails, neither write is committed.
    final batch = _firestore.batch();

    batch.update(clientDocument, {
      'channels': FieldValue.arrayUnion([
        channelData,
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(activityDocument, activityData);

    await batch.commit();
  }

  Future<void> updateChannel(
      String clientId,
      ChannelModel channel,
      ) async {
    final cleanClientId = clientId.trim();

    if (cleanClientId.isEmpty) {
      throw Exception('Client ID is required.');
    }

    final clientDocument = _clients.doc(cleanClientId);
    final snapshot = await clientDocument.get();

    if (!snapshot.exists) {
      throw Exception('Client not found.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final rawChannels =
        data['channels'] as List<dynamic>? ?? <dynamic>[];

    Map<String, dynamic>? oldChannelData;

    final newChannelData = <String, dynamic>{
      'id': channel.id,
      ...channel.toMap(),
    };

    final updatedChannels = rawChannels.map((raw) {
      if (raw is! Map) {
        return raw;
      }

      final existing = Map<String, dynamic>.from(raw);

      if (existing['id']?.toString() != channel.id) {
        return existing;
      }

      oldChannelData = existing;
      return newChannelData;
    }).toList();

    if (oldChannelData == null) {
      throw Exception('Channel not found.');
    }

    final oldData = oldChannelData!;

    final changedFields = <String, Map<String, dynamic>>{};

    const trackedFields = <String>[
      'channelType',
      'name',
      'status',
      'whatsappType',
      'channelValue',
      'phoneNumber',
      'phoneNumberId',
      'fbmId',
      'wabaId',
      'callCenterValue',
      'whatsappChannelToLogCalls',
      'aiCallSummaryEnabled',
    ];

    for (final field in trackedFields) {
      final oldValue = oldData[field];
      final newValue = newChannelData[field];

      if (_channelValuesDifferent(oldValue, newValue)) {
        changedFields[field] = <String, dynamic>{
          'oldValue': oldValue,
          'newValue': newValue,
        };
      }
    }

    // Nothing materially changed. Do not generate a false audit event.
    if (changedFields.isEmpty) {
      return;
    }

    final channelName = _channelDisplayName(channel);
    final changeSummary =
    _channelChangeSummary(changedFields);

    final activityDocument = _activity(cleanClientId).doc();

    final activityData = await _buildActivityData(
      clientId: cleanClientId,
      type: 'channel',
      action: 'updated',
      title: 'Channel updated',
      description: '$channelName was updated. $changeSummary',
      metadata: {
        // Keep the most useful fields first because the current
        // Activity screen previews the first metadata entries.
        'channelName': channelName,
        'channelType': channel.channelType,
        'changes': changeSummary,
        'channelId': channel.id,
        'changeCount': changedFields.length,
        'changedFields': changedFields,
        'previousChannel': _cleanActivityMap(oldData),
        'updatedChannel': _cleanActivityMap(newChannelData),
      },
    );

    // The channel change and the activity event are atomic.
    // This prevents a saved change (for example Active -> Inactive)
    // from ever existing without its corresponding audit entry.
    final batch = _firestore.batch();

    batch.update(clientDocument, {
      'channels': updatedChannels,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(activityDocument, activityData);

    await batch.commit();
  }

  Future<void> deleteChannel(
      String clientId,
      String channelId,
      ) async {
    final cleanClientId = clientId.trim();
    final cleanChannelId = channelId.trim();

    if (cleanClientId.isEmpty) {
      throw Exception('Client ID is required.');
    }

    if (cleanChannelId.isEmpty) {
      throw Exception('Channel ID is required.');
    }

    final clientDocument = _clients.doc(cleanClientId);
    final snapshot = await clientDocument.get();

    if (!snapshot.exists) {
      throw Exception('Client not found.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final rawChannels =
        data['channels'] as List<dynamic>? ?? <dynamic>[];

    Map<String, dynamic>? deletedChannel;

    final updatedChannels = rawChannels.where((raw) {
      if (raw is! Map) {
        return true;
      }

      final map = Map<String, dynamic>.from(raw);

      if (map['id']?.toString() == cleanChannelId) {
        deletedChannel = map;
        return false;
      }

      return true;
    }).toList();

    if (deletedChannel == null) {
      throw Exception('Channel not found.');
    }

    final channelData =
    Map<String, dynamic>.from(deletedChannel!);
    final channelName =
    _channelMapDisplayName(channelData);

    final activityDocument = _activity(cleanClientId).doc();

    final activityData = await _buildActivityData(
      clientId: cleanClientId,
      type: 'channel',
      action: 'deleted',
      title: 'Channel deleted',
      description:
      '$channelName was deleted from the client.',
      metadata: {
        'channelName': channelName,
        'channelType':
        channelData['channelType']?.toString() ?? '',
        'status':
        channelData['status']?.toString() ?? '',
        'channelId': cleanChannelId,
        'deletedChannel':
        _cleanActivityMap(channelData),
      },
    );

    final batch = _firestore.batch();

    batch.update(clientDocument, {
      'channels': updatedChannels,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(activityDocument, activityData);

    await batch.commit();
  }

// ============================================================
// CHANNEL ACTIVITY HELPERS
// ============================================================

  Map<String, dynamic> _channelActivityMetadata(
      ChannelModel channel,
      ) {
    return {
      'channelType': channel.channelType,
      'name': channel.name,
      'status': channel.status,
      'whatsappType': channel.whatsappType,
      'channelValue': channel.channelValue,
      'phoneNumber': channel.phoneNumber,
      'phoneNumberId': channel.phoneNumberId,
      'fbmId': channel.fbmId,
      'wabaId': channel.wabaId,
      'callCenterValue': channel.callCenterValue,
      'whatsappChannelToLogCalls':
      channel.whatsappChannelToLogCalls,
      'aiCallSummaryEnabled':
      channel.aiCallSummaryEnabled,
    };
  }

  bool _channelValuesDifferent(
      dynamic oldValue,
      dynamic newValue,
      ) {
    if (oldValue == null && newValue == null) {
      return false;
    }

    final oldText = oldValue?.toString().trim() ?? '';
    final newText = newValue?.toString().trim() ?? '';

    return oldText != newText;
  }

  String _channelChangeSummary(
      Map<String, Map<String, dynamic>> changedFields,
      ) {
    final changes = <String>[];

    for (final entry in changedFields.entries) {
      final label = _channelFieldLabel(entry.key);
      final oldValue =
      _displayActivityValue(entry.value['oldValue']);
      final newValue =
      _displayActivityValue(entry.value['newValue']);

      changes.add(
        '$label changed from "$oldValue" to "$newValue"',
      );
    }

    if (changes.isEmpty) {
      return 'Channel details changed.';
    }

    return '${changes.join('. ')}.';
  }

  String _channelFieldLabel(String field) {
    switch (field) {
      case 'channelType':
        return 'Channel type';
      case 'name':
        return 'Name';
      case 'status':
        return 'Status';
      case 'whatsappType':
        return 'WhatsApp type';
      case 'channelValue':
        return 'Channel value';
      case 'phoneNumber':
        return 'Phone number';
      case 'phoneNumberId':
        return 'Phone Number ID';
      case 'fbmId':
        return 'FBM ID';
      case 'wabaId':
        return 'WABA ID';
      case 'callCenterValue':
        return 'Call center value';
      case 'whatsappChannelToLogCalls':
        return 'WhatsApp channel used to log calls';
      case 'aiCallSummaryEnabled':
        return 'AI call summary';
      default:
        return field;
    }
  }

  String _displayActivityValue(dynamic value) {
    if (value == null) {
      return 'empty';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return 'empty';
    }

    return text;
  }

  Map<String, dynamic> _cleanActivityMap(
      Map<String, dynamic> source,
      ) {
    final result = <String, dynamic>{};

    for (final entry in source.entries) {
      final value = entry.value;

      // These values are Firestore-safe already. Nested maps/lists
      // are retained so the full before/after state remains auditable.
      if (value is Map) {
        result[entry.key] =
        Map<String, dynamic>.from(value);
      } else if (value is List) {
        result[entry.key] = List<dynamic>.from(value);
      } else {
        result[entry.key] = value;
      }
    }

    return result;
  }

  String _channelActivityDescription(
      ChannelModel channel, {
        required String action,
      }) {
    final name = _channelDisplayName(channel);

    if (channel.channelType.trim().isEmpty) {
      return 'Channel $name was $action.';
    }

    return '$name (${channel.channelType}) was $action.';
  }

  String _channelDisplayName(
      ChannelModel channel,
      ) {
    switch (channel.channelType.trim()) {
      case 'WhatsApp':
        return channel.name.trim().isNotEmpty
            ? channel.name.trim()
            : 'WhatsApp';

      case 'Instagram':
        return channel.channelValue.trim().isNotEmpty
            ? channel.channelValue.trim()
            : 'Instagram';

      case 'Facebook':
        return channel.channelValue.trim().isNotEmpty
            ? channel.channelValue.trim()
            : 'Facebook';

      case 'TikTok':
        return channel.channelValue.trim().isNotEmpty
            ? channel.channelValue.trim()
            : 'TikTok';

      case 'Telegram':
        return channel.channelValue.trim().isNotEmpty
            ? channel.channelValue.trim()
            : 'Telegram';

      case 'Website Widget':
        return channel.channelValue.trim().isNotEmpty
            ? channel.channelValue.trim()
            : 'Website Widget';

      case 'Bevatel Call Center':
        return channel.callCenterValue.trim().isNotEmpty
            ? channel.callCenterValue.trim()
            : 'Bevatel Call Center';

      default:
        return channel.name.trim().isNotEmpty
            ? channel.name.trim()
            : 'Channel';
    }
  }

  String _channelMapDisplayName(
      Map<String, dynamic> channel,
      ) {
    final type =
        channel['channelType']?.toString().trim() ?? '';

    final name =
        channel['name']?.toString().trim() ?? '';

    final value =
        channel['channelValue']?.toString().trim() ?? '';

    final callCenter =
        channel['callCenterValue']?.toString().trim() ?? '';

    switch (type) {
      case 'WhatsApp':
        return name.isNotEmpty ? name : 'WhatsApp';

      case 'Instagram':
        return value.isNotEmpty ? value : 'Instagram';

      case 'Facebook':
        return value.isNotEmpty ? value : 'Facebook';

      case 'TikTok':
        return value.isNotEmpty ? value : 'TikTok';

      case 'Telegram':
        return value.isNotEmpty ? value : 'Telegram';

      case 'Website Widget':
        return value.isNotEmpty ? value : 'Website Widget';

      case 'Bevatel Call Center':
        return callCenter.isNotEmpty
            ? callCenter
            : 'Bevatel Call Center';

      default:
        return name.isNotEmpty ? name : 'Channel';
    }
  }

  // ============================================================
  // DELETE CLIENT
  // ============================================================

  Future<void> deleteClient(String clientId) async {
    await _clients.doc(clientId).delete();
  }

  // ============================================================
  // FAST BULK DELETE CLIENTS
  //
  // Firestore allows a maximum of 500 writes per batch.
  //
  // Therefore large deletions are split into batches of 500.
  //
  // This is dramatically faster than:
  //
  // await deleteClient(...)
  // await deleteClient(...)
  // await deleteClient(...)
  //
  // because each batch is committed in one network operation.
  // ============================================================

  Future<int> bulkDeleteClients(
      List<String> clientIds, {
        void Function(int deleted, int total)? onProgress,
        bool Function()? isCancelled,
      }) async {
    final ids = clientIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) {
      onProgress?.call(0, 0);
      return 0;
    }

    const batchLimit = 500;

    int deleted = 0;

    for (int start = 0; start < ids.length; start += batchLimit) {
      if (isCancelled?.call() ?? false) {
        break;
      }

      final end = (start + batchLimit > ids.length)
          ? ids.length
          : start + batchLimit;

      final batch = _firestore.batch();

      for (final clientId in ids.sublist(start, end)) {
        batch.delete(_clients.doc(clientId));
      }

      await batch.commit();

      deleted += end - start;

      onProgress?.call(
        deleted,
        ids.length,
      );

      if (isCancelled?.call() ?? false) {
        break;
      }
    }

    return deleted;
  }

  // ============================================================
  // TASKS
  // ============================================================

  Stream<List<OnboardingTaskModel>> watchAllTasks() {
    return _tasks.snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map(OnboardingTaskModel.fromFirestore)
          .toList();

      tasks.sort((a, b) {
        final aDate =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      return tasks;
    });
  }

  Stream<List<OnboardingTaskModel>> watchMyTasks() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value(
        const <OnboardingTaskModel>[],
      );
    }

    return _tasks
        .where(
      'assignedTo',
      isEqualTo: user.uid,
    )
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map(OnboardingTaskModel.fromFirestore)
          .toList();

      tasks.sort((a, b) {
        final aDate =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      return tasks;
    });
  }

  // ============================================================
  // AGENTS
  // ============================================================

  Stream<Map<String, Map<String, String>>> watchAllAgentsByRole() {
    return _firestore.collection('users').where('role', isNotEqualTo: null).snapshots().map((snapshot) {
      final result = <String, Map<String, String>>{
        'onboarding_agent': {},
        'support_agent': {},
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role']?.toString().trim();
        if (role != 'onboarding_agent' && role != 'support_agent') continue;

        final name = data['displayName']?.toString() ??
            data['username']?.toString() ??
            data['email']?.toString() ??
            doc.id;

        result[role]![doc.id] = name;
      }
      return result;
    });
  }

  Stream<Map<String, String>> watchAgents({
    String? role,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('users');

    if (role != null) {
      query = query.where(
        'role',
        isEqualTo: role,
      );
    } else {
      query = query.where(
        'role',
        isNotEqualTo: null,
      );
    }

    return query.snapshots().map((snapshot) {
      final agents = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final name = data['displayName']?.toString() ??
            data['username']?.toString() ??
            data['email']?.toString() ??
            doc.id;

        agents[doc.id] = name;
      }

      return agents;
    });
  }

  // ============================================================
  // ACTIVE TASK
  // ============================================================

  Future<OnboardingTaskModel?> getActiveTask() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final snapshot = await _tasks
        .where(
      'assignedTo',
      isEqualTo: user.uid,
    )
        .where(
      'status',
      isEqualTo: 'In Progress',
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return OnboardingTaskModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ============================================================
  // CREATE TASK
  // ============================================================

  Future<String> createTask({
    String task = '',
    required String taskType,
    String? clientId,
    String? clientName,
    String? accNumber,
    String? department,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to create a task.',
      );
    }

    final cleanTask = task.trim();
    _log.ui('Started task: $taskType ${cleanTask.isNotEmpty ? "($cleanTask)" : ""}');
    final cleanTaskType = taskType.trim();
    final cleanClientId = clientId?.trim() ?? '';
    final cleanClientName = clientName?.trim() ?? '';
    final cleanAccNumber = accNumber?.trim() ?? '';
    final cleanDepartment = department?.trim() ?? '';

    // ============================================================
    // VALIDATION
    // ============================================================

    if (cleanTaskType.isEmpty) {
      throw Exception(
        'Task type is required.',
      );
    }

    if (cleanTaskType != 'Internal' &&
        cleanClientId.isEmpty) {
      throw Exception(
        'A client is required for this task type.',
      );
    }

    if (cleanTaskType == 'Internal' &&
        cleanDepartment.isEmpty) {
      throw Exception(
        'A department is required for an internal task.',
      );
    }

    // ============================================================
    // TASK CREATION
    // ============================================================

    final document = _tasks.doc();

    final now = FieldValue.serverTimestamp();

    await document.set({
      'task': cleanTask,
      'taskType': cleanTaskType,
      'status': 'In Progress',
      'assignedTo': user.uid,
      'createdBy': user.uid,
      'clientId': cleanClientId,
      'clientName': cleanClientName,
      'accNumber': cleanAccNumber,
      'department': cleanDepartment,
      'createdAt': now,
      'startedAt': now,
      'finishedAt': null,
      'updatedAt': now,
    });

    // ============================================================
    // ACTIVITY LOG
    // ============================================================

    if (cleanTaskType != 'Internal' &&
        cleanClientId.isNotEmpty) {
      try {
        await addActivity(
          clientId: cleanClientId,
          type: 'task',
          action: 'started',
          title: 'Task started',
          description: cleanTask,
          metadata: {
            'taskId': document.id,
            'taskType': cleanTaskType,
          },
        );
      } catch (_) {
        // Task creation remains successful.
      }
    }

    return document.id;
  }

  // ============================================================
  // FINISH TASK
  // ============================================================

  Future<void> finishTask(String taskId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to finish a task.',
      );
    }

    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception(
        'Task ID is required.',
      );
    }

    final document = _tasks.doc(cleanTaskId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw Exception(
        'Task not found.',
      );
    }

    final data =
        snapshot.data() ?? <String, dynamic>{};

    final assignedTo =
        data['assignedTo']?.toString() ?? '';

    if (assignedTo != user.uid) {
      throw Exception(
        'You are not allowed to finish this task.',
      );
    }

    if (data['status']?.toString() == 'Finished') {
      return;
    }

    final finishedAt = DateTime.now();

    final startedAt =
    _taskDateTime(data['startedAt']);

    await document.update({
      'status': 'Finished',
      'finishedAt':
      Timestamp.fromDate(finishedAt),
      'updatedAt':
      FieldValue.serverTimestamp(),
    });

    final clientId =
        data['clientId']?.toString() ?? '';

    if (clientId.isNotEmpty) {
      final durationSeconds = startedAt == null
          ? null
          : finishedAt
          .difference(startedAt)
          .inSeconds;

      try {
        await addActivity(
          clientId: clientId,
          type: 'task',
          action: 'finished',
          title: 'Task finished',
          description:
          data['task']?.toString() ?? '',
          metadata: {
            'taskId': cleanTaskId,
            'taskType':
            data['taskType']?.toString() ?? '',
            if (durationSeconds != null)
              'durationSeconds':
              durationSeconds,
          },
        );
      } catch (_) {
        // Task completion remains successful.
      }
    }
  }

  // ============================================================
  // EDIT TASK
  // ============================================================

  Future<void> updateTask({
    required String taskId,
    String task = '',
    required String taskType,
    String? clientId,
    String? clientName,
    String? accNumber,
    String? department,
    DateTime? startedAt,
  }) async
  {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to edit a task.',
      );
    }

    final cleanTaskId = taskId.trim();
    final cleanTask = task.trim();
    final cleanTaskType = taskType.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Task ID is required.');
    }

    if (cleanTaskType.isEmpty) {
      throw Exception('Task type is required.');
    }

    final document = _tasks.doc(cleanTaskId);
    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw Exception('Task not found.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};

    final assignedTo =
        data['assignedTo']?.toString().trim() ?? '';

    if (assignedTo != user.uid) {
      throw Exception(
        'You are not allowed to edit this task.',
      );
    }

    final cleanClientId = clientId?.trim() ?? '';
    final cleanClientName = clientName?.trim() ?? '';
    final cleanAccNumber = accNumber?.trim() ?? '';
    final cleanDepartment = department?.trim() ?? '';

    if (cleanTaskType != 'Internal' &&
        cleanClientId.isEmpty) {
      throw Exception(
        'A client is required for this task type.',
      );
    }

    if (cleanTaskType == 'Internal' &&
        cleanDepartment.isEmpty) {
      throw Exception(
        'A department is required for an internal task.',
      );
    }

    final existingFinishedAt = _taskDateTime(
      data['finishedAt'],
    );

    if (startedAt != null) {
      if (startedAt.isAfter(DateTime.now())) {
        throw Exception(
          'Task start time cannot be in the future.',
        );
      }

      if (existingFinishedAt != null &&
          !startedAt.isBefore(existingFinishedAt)) {
        throw Exception(
          'Task start time must be before the finish time.',
        );
      }
    }

    await document.update({
      'task': cleanTask,
      'taskType': cleanTaskType,
      'clientId': cleanClientId,
      'clientName': cleanClientName,
      'accNumber': cleanAccNumber,
      'department': cleanDepartment,
      if (startedAt != null)
        'startedAt': Timestamp.fromDate(startedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  // ============================================================
  // DELETE TASK FROM CALCULATED TASK TIME ONLY
  // ============================================================

  Future<void> deleteTask(String taskId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to delete a task.',
      );
    }

    final cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw Exception('Task ID is required.');
    }

    final document = _tasks.doc(cleanTaskId);
    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw Exception('Task not found.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};

    final assignedTo = data['assignedTo']?.toString().trim() ?? '';

    if (assignedTo != user.uid) {
      throw Exception(
        'You are not allowed to delete this task.',
      );
    }

    // Delete ONLY the onboarding_tasks document.
    //
    // We intentionally do NOT touch:
    // clients/{clientId}/activity/*
    //
    // Therefore the task remains visible in the Activity tab as an
    // audit/history event, while it is removed from all task-time
    // calculations that read from onboarding_tasks.
    await document.delete();
  }

  DateTime? _taskDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String &&
        value.trim().isNotEmpty) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }

  // ============================================================
  // SYNC VERIFICATION STATUS TO ZOHO CRM
  // ============================================================

  Future<void> updateVerificationStatusInZoho({
    required String accountNumber,
    required String verificationStatus,
  }) async {
    final cleanAccountNumber =
    accountNumber.trim();

    final cleanVerificationStatus =
    verificationStatus.trim();

    if (cleanAccountNumber.isEmpty) {
      throw Exception(
        'Client ACC number is required to sync verification status with Zoho CRM.',
      );
    }

    if (cleanVerificationStatus.isEmpty) {
      throw Exception(
        'Verification status is required to sync with Zoho CRM.',
      );
    }

    final callable =
    _functions.httpsCallable(
      'updateVerificationStatus',
    );

    try {
      await callable.call({
        'accountNumber':
        cleanAccountNumber,
        'verificationStatus':
        cleanVerificationStatus,
      });
    } on FirebaseFunctionsException catch (e) {
      final message =
      e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Unable to sync verification status with Zoho CRM.';

      throw Exception(message);
    } catch (e) {
      throw Exception(
        'Unable to sync verification status with Zoho CRM: $e',
      );
    }
  }

  // ============================================================
  // UPDATE VERIFICATION CHECKLIST
  // ============================================================

  Future<void> updateVerificationChecklist({
    required String clientId,
    required Map<String, bool> checklist,
    required String verificationStatus,
  }) async {
    _log.ui('Updated verification checklist for $clientId');
    await _clients.doc(clientId).update({
      'verificationChecklist':
      Map<String, bool>.from(checklist),
      'verificationStatus':
      verificationStatus.trim(),
      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE CHATBOT STATUS IN ZOHO
  // ============================================================

  Future<void> updateChatbotStatusInZoho({
    required String accountNumber,
    required String chatbotStatus,
  }) async {
    final cleanAccountNumber = accountNumber.trim();
    final cleanChatbotStatus = chatbotStatus.trim();

    if (cleanAccountNumber.isEmpty) {
      throw Exception(
        'Client ACC number is required to sync chatbot status with Zoho CRM.',
      );
    }

    if (cleanChatbotStatus.isEmpty) {
      throw Exception(
        'Chatbot status is required to sync with Zoho CRM.',
      );
    }

    final callable = _functions.httpsCallable(
      'updateChatbotStatus',
    );

    try {
      await callable.call({
        'accountNumber': cleanAccountNumber,
        'chatbotStatus': cleanChatbotStatus,
      });
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Unable to sync chatbot status with Zoho CRM.';
      throw Exception(message);
    } catch (e) {
      throw Exception(
        'Unable to sync chatbot status with Zoho CRM: $e',
      );
    }
  }
}

