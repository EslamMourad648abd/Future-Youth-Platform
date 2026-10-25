import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'future_youth_home.dart';

class LearningWorkflowScreen extends StatefulWidget {
  const LearningWorkflowScreen({super.key, required this.kind, required this.title});
  final String kind;
  final String title;

  @override
  State<LearningWorkflowScreen> createState() => _LearningWorkflowScreenState();
}

class _LearningWorkflowScreenState extends State<LearningWorkflowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _schoolYearController = TextEditingController();
  final _videoUrlController = TextEditingController();
  bool _saving = false;
  String _paymentMethod = 'instapay';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _schoolYearController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  String get _collection {
    switch (widget.kind) {
      case 'teacher_content':
        return 'playlists';
      case 'teacher_video':
      case 'teacher_reports':
      case 'teacher_analytics':
      case 'admin_review':
      case 'student_previews':
        return 'videos';
      case 'teacher_management':
      case 'teacher_profile':
      case 'student_catalog':
        return 'teacherProfiles';
      case 'payments':
        return 'paymentRequests';
      case 'parent_children':
        return 'studentProfiles';
      case 'parent_progress':
        return 'examResults';
      case 'student_learning':
        return 'playlists';
      case 'student_exams':
        return 'examResults';
      default:
        return 'playlists';
    }
  }

  bool get _canCreate {
    final role = AuthService.role.toLowerCase();
    return (widget.kind == 'teacher_content' && role == 'teacher') ||
        (widget.kind == 'teacher_video' && role == 'teacher') ||
        (widget.kind == 'teacher_profile' && role == 'teacher') ||
        (widget.kind == 'parent_children' && role == 'parent') ||
        (widget.kind == 'payments' && role == 'parent');
  }

  bool get _isReview => widget.kind == 'admin_review';
  bool get _isPayments => widget.kind == 'payments';
  bool get _isParentChildren => widget.kind == 'parent_children';
  bool get _isTeacherContent => widget.kind == 'teacher_content';
  bool get _isTeacherVideo => widget.kind == 'teacher_video';
  bool get _isTeacherProfile => widget.kind == 'teacher_profile';

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final now = FieldValue.serverTimestamp();
      if (_isTeacherContent) {
        await FirebaseFirestore.instance.collection('playlists').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'teacherUid': user.uid,
          'subject': _descriptionController.text.trim(),
          'schoolYear': _schoolYearController.text.trim(),
          'status': 'draft',
          'createdAt': now,
          'updatedAt': now,
        });
      } else if (_isTeacherProfile) {
        final subjects = _descriptionController.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
        await FirebaseFirestore.instance.collection('teacherProfiles').doc(user.uid).set({
          'uid': user.uid,
          'displayName': _titleController.text.trim(),
          'subjects': subjects,
          'schoolYears': _schoolYearController.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
          'approvalStatus': 'pending',
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      } else if (_isTeacherVideo) {
        await FirebaseFirestore.instance.collection('videos').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'videoUrl': _videoUrlController.text.trim(),
          'teacherUid': user.uid,
          'playlistId': _schoolYearController.text.trim(),
          'status': 'pending_admin_review',
          'moderationStatus': 'not_configured',
          'isFreePreview': false,
          'createdAt': now,
          'updatedAt': now,
        });
      } else if (_isParentChildren) {
        await FirebaseFirestore.instance.collection('studentProfiles').add({
          'displayName': _titleController.text.trim(),
          'email': _emailController.text.trim(),
          'nationalId': _nationalIdController.text.trim(),
          'schoolYear': _schoolYearController.text.trim(),
          'parentUid': user.uid,
          'invitationStatus': 'invitation_requested',
          'accountStatus': 'pending',
          'createdAt': now,
          'updatedAt': now,
        });
      } else if (_isPayments) {
        await FirebaseFirestore.instance.collection('paymentRequests').add({
          'parentUid': user.uid,
          'amount': null,
          'currency': 'EGP',
          'method': _paymentMethod,
          'reference': _titleController.text.trim(),
          'notes': _descriptionController.text.trim(),
          'status': 'pending_verification',
          'createdAt': now,
          'verifiedAt': null,
          'verifiedBy': null,
        });
      }
      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _emailController.clear();
      _nationalIdController.clear();
      _schoolYearController.clear();
      _videoUrlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isParentChildren
          ? 'Child profile request saved. An invitation still needs to be sent by a trusted backend.'
          : _isPayments
            ? 'Payment request saved as pending. No payment has been verified.'
            : _isTeacherVideo
              ? 'Video metadata submitted for Admin review. No video file was uploaded and AI moderation is not connected.'
              : _isTeacherProfile
                ? 'Teacher profile submitted for Admin approval.'
                : 'Draft playlist saved. Content is not published until reviewed and approved.'),
      ));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ${e.message ?? e.code}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewVideo(DocumentSnapshot<Map<String, dynamic>> doc, bool approve) async {
    final role = AuthService.role.toLowerCase();
    if (role != 'admin' && role != 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can review content.')));
      return;
    }
    final reasonController = TextEditingController();
    final timecodeController = TextEditingController();
    if (!approve) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject video'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: timecodeController, decoration: const InputDecoration(labelText: 'Timecode (e.g. 02:15)')),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
          ],
        ),
      );
      if (result != true) {
        reasonController.dispose();
        timecodeController.dispose();
        return;
      }
      if (reasonController.text.trim().isEmpty || timecodeController.text.trim().isEmpty) {
        reasonController.dispose();
        timecodeController.dispose();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A rejection reason and timecode are required.')));
        return;
      }
    }
    try {
      await doc.reference.update({
        'status': approve ? 'approved' : 'rejected',
        'adminDecision': approve ? 'approved' : 'rejected',
        'rejectionReason': approve ? null : reasonController.text.trim(),
        'rejectionTimecode': approve ? null : timecodeController.text.trim(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: ${e.message ?? e.code}')));
    } finally {
      reasonController.dispose();
      timecodeController.dispose();
    }
  }

  Future<void> _reviewTeacherProfile(DocumentSnapshot<Map<String, dynamic>> doc, bool approve) async {
    final role = AuthService.role.toLowerCase();
    if (role != 'admin' && role != 'superadmin') return;
    final reasonController = TextEditingController();
    if (!approve) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject teacher profile'),
          content: TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
          ],
        ),
      );
      if (result != true || reasonController.text.trim().isEmpty) {
        reasonController.dispose();
        return;
      }
    }
    try {
      await doc.reference.update({
        'approvalStatus': approve ? 'approved' : 'rejected',
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': approve ? null : reasonController.text.trim(),
      });
    } on FirebaseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: ${e.message ?? e.code}')));
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _selectTeacher(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || AuthService.role.toLowerCase() != 'student') return;
    final teacher = doc.data() ?? {};
    final subjects = (teacher['subjects'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final subject = subjects.isNotEmpty ? subjects.first : '';
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This teacher has no approved subjects listed yet.')));
      return;
    }
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm teacher selection'),
        content: Text('Select ${teacher['displayName'] ?? 'this teacher'} for $subject?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm again'),
        content: const Text('This selection will be recorded for the chosen subject. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm selection')),
        ],
      ),
    );
    if (second != true) return;
    final subjectKey = subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    try {
      await FirebaseFirestore.instance.collection('teacherSelections').doc('${user.uid}_$subjectKey').set({
        'studentUid': user.uid,
        'teacherUid': doc.id,
        'subjectId': subject,
        'confirmationCount': 2,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher selection saved. Parent payment confirmation is still required.')));
    } on FirebaseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save selection: ${e.message ?? e.code}')));
    }
  }

  Query<Map<String, dynamic>> _query() {
    final user = FirebaseAuth.instance.currentUser;
    final role = AuthService.role.toLowerCase();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(_collection);
    if (_collection == 'playlists' && role == 'teacher') {
      query = query.where('teacherUid', isEqualTo: user?.uid);
    } else if (_collection == 'studentProfiles' && role == 'parent') {
      query = query.where('parentUid', isEqualTo: user?.uid);
    } else if (_collection == 'paymentRequests' && role == 'parent') {
      query = query.where('parentUid', isEqualTo: user?.uid);
    } else if (_collection == 'videos' && role == 'teacher') {
      query = query.where('teacherUid', isEqualTo: user?.uid);
    } else if (_collection == 'videos' && role == 'student') {
      query = query.where('status', isEqualTo: 'approved').where('isFreePreview', isEqualTo: true);
    } else if (_collection == 'playlists' && role == 'student') {
      query = query.where('status', isEqualTo: 'published');
    } else if (_collection == 'examResults' && role == 'parent') {
      query = query.where('parentUid', isEqualTo: user?.uid);
    } else if (_collection == 'examResults' && role == 'student') {
      query = query.where('studentUid', isEqualTo: user?.uid);
    } else if (_collection == 'teacherProfiles' && role == 'teacher') {
      query = query.where('uid', isEqualTo: user?.uid);
    } else if (_collection == 'teacherProfiles' && role == 'student') {
      query = query.where('approvalStatus', isEqualTo: 'approved');
    } else if (_collection == 'teacherProfiles' && (role == 'admin' || role == 'superadmin')) {
      query = query.where('approvalStatus', isEqualTo: 'pending');
    }
    return query.limit(100);
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.role.toLowerCase();
    final canReview = (_isReview || widget.kind == 'teacher_management') && (role == 'admin' || role == 'superadmin');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: futureYouthNavy,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      floatingActionButton: _canCreate ? FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: futureYouthGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_isPayments ? 'Add payment request' : _isParentChildren ? 'Add child' : 'New playlist'),
      ) : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(icon: Icons.lock_outline, title: 'Unable to load this workspace',
              message: 'The database denied this request or is not configured for this feature. Check Firestore rules and the selected Firebase project.\n\n${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: futureYouthNavy));
          }
          final docs = snapshot.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_isTeacherProfile) _MessageState.compact(
                icon: Icons.verified_user_outlined,
                title: 'Admin approval required',
                message: 'The profile remains pending until an Admin approves it. Approved profiles can appear in student discovery.',
              ),
              if (_isTeacherVideo) _MessageState.compact(
                icon: Icons.info_outline,
                title: 'Metadata only',
                message: 'This submits a video URL or storage reference for review. Uploading files and automated AI checks are not connected in this iteration.',
              ),
              if (_isTeacherContent) _MessageState.compact(
                icon: Icons.info_outline,
                title: 'Draft-first publishing',
                message: 'A playlist is saved as a draft. Video upload, automated AI moderation, and publication require the follow-up backend integration.',
              ),
              if (_isPayments) _MessageState.compact(
                icon: Icons.payments_outlined,
                title: 'Manual verification workflow',
                message: 'Available request methods: InstaPay, Vodafone Cash, Orange Cash, and Etisalat Cash. Requests remain pending until an authorized verifier confirms them.',
              ),
              if (_isParentChildren) _MessageState.compact(
                icon: Icons.mark_email_unread_outlined,
                title: 'Invitation status',
                message: 'This form records a child profile and invitation request. Sending email and creating the Student Firebase Auth account must be done by a trusted Cloud Function.',
              ),
              if (docs.isEmpty) const _MessageState(
                icon: Icons.inbox_outlined,
                title: 'Nothing here yet',
                message: 'Items will appear here when they are created or submitted.',
              ) else ...docs.map((doc) => _itemCard(doc, canReview)),
            ],
          );
        },
      ),
    );
  }

  Widget _itemCard(DocumentSnapshot<Map<String, dynamic>> doc, bool canReview) {
    final data = doc.data() ?? {};
    final title = (data['title'] ?? data['displayName'] ?? data['reference'] ?? 'Untitled').toString();
    final rejectionReason = data['rejectionReason'];
    final status = (data['status'] ?? data['approvalStatus'] ?? data['invitationStatus'] ?? 'draft').toString();
    final subtitle = (data['description'] ?? data['notes'] ?? data['schoolYear'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E7F0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.article_outlined, color: futureYouthGreen),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Chip(label: Text(status.replaceAll('_', ' '))),
          ]),
          if (subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(subtitle)),
          if (rejectionReason != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Rejection: $rejectionReason')),
          if (widget.kind == 'student_catalog' && AuthService.role.toLowerCase() == 'student' && status == 'approved') Padding(
            padding: const EdgeInsets.only(top: 14),
            child: FilledButton.icon(
              onPressed: () => _selectTeacher(doc),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Select this teacher'),
            ),
          ),
          if (canReview && status != 'approved' && status != 'rejected') Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: () => _collection == 'teacherProfiles' ? _reviewTeacherProfile(doc, true) : _reviewVideo(doc, true), icon: const Icon(Icons.check), label: const Text('Approve')),
              OutlinedButton.icon(onPressed: () => _collection == 'teacherProfiles' ? _reviewTeacherProfile(doc, false) : _reviewVideo(doc, false), icon: const Icon(Icons.close), label: const Text('Reject')),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    _titleController.clear();
    _descriptionController.clear();
    _emailController.clear();
    _nationalIdController.clear();
    _schoolYearController.clear();
    _videoUrlController.clear();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(_isPayments ? 'Payment request' : _isParentChildren ? 'Child profile' : _isTeacherVideo ? 'Submit video metadata' : _isTeacherProfile ? 'Teacher profile' : 'New playlist'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: _isPayments ? 'Payment reference' : _isParentChildren ? 'Child full name' : _isTeacherProfile ? 'Teacher display name' : _isTeacherVideo ? 'Video title' : 'Playlist title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (_isTeacherProfile) ...[
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Subjects (comma separated)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter at least one subject' : null),
                  TextFormField(controller: _schoolYearController, decoration: const InputDecoration(labelText: 'School years (comma separated)')),
                ] else if (_isTeacherVideo) ...[
                  TextFormField(controller: _schoolYearController, decoration: const InputDecoration(labelText: 'Playlist ID')),
                  TextFormField(controller: _videoUrlController, decoration: const InputDecoration(labelText: 'Video URL or storage reference'), keyboardType: TextInputType.url,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Video URL or storage reference is required' : null),
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description / curriculum notes')),
                ] else if (_isParentChildren) ...[
                  TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Student email'), keyboardType: TextInputType.emailAddress),
                  TextFormField(controller: _nationalIdController, decoration: const InputDecoration(labelText: 'National ID')),
                  TextFormField(controller: _schoolYearController, decoration: const InputDecoration(labelText: 'School year')),
                ] else if (_isTeacherContent) ...[
                  TextFormField(controller: _schoolYearController, decoration: const InputDecoration(labelText: 'School year')),
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Subject / description')),
                ] else if (_isPayments) ...[
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment method'),
                    items: const [
                      DropdownMenuItem(value: 'instapay', child: Text('InstaPay')),
                      DropdownMenuItem(value: 'vodafone_cash', child: Text('Vodafone Cash')),
                      DropdownMenuItem(value: 'orange_cash', child: Text('Orange Cash')),
                      DropdownMenuItem(value: 'etisalat_cash', child: Text('Etisalat Cash')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => _paymentMethod = v); },
                  ),
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Notes / transaction reference')),
                ],
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: _saving ? null : () { if (_formKey.currentState?.validate() ?? false) Navigator.pop(dialogContext, true); }, child: Text(isAr ? 'حفظ' : 'Save')),
        ],
      )),
    );
    if (saved == true) await _save();
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.title, required this.message});
  const _MessageState.compact({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: futureYouthNavy),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
      ]),
    ),
  );
}
