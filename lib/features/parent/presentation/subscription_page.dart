import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../services/localization_service.dart';

class SubscriptionPage extends StatefulWidget {
  final String? invoiceId;
  final String? studentId;
  final String? courseId;

  const SubscriptionPage({
    super.key,
    this.invoiceId,
    this.studentId,
    this.courseId,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _referenceCtrl = TextEditingController();

  bool loading = true;
  bool submitting = false;
  String? selectedPaymentMethod = 'instapay'; // instapay, vodafone_cash, orange_cash, etisalat_cash

  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> courses = [];

  String? selectedStudentId;
  String? selectedCourseId;
  double coursePrice = 250.0; // EGP

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    super.dispose();
  }

  double _priceForCourse(String? id) {
    for (final course in courses) {
      if (course['id']?.toString() == id) {
        return (course['price'] as num?)?.toDouble() ?? 250.0;
      }
    }
    return 250.0;
  }

  Future<void> _loadCheckoutData() async {
    final parentUser = FirebaseAuth.instance.currentUser;
    if (parentUser == null) return;

    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .where('parentId', isEqualTo: parentUser.uid)
          .get();

      final studentList = studentSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      final courseSnapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.courses)
          .where('status', isEqualTo: 'published')
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      final courseList = courseSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      if (!mounted) return;
      setState(() {
        students = studentList;
        courses = courseList;
        selectedStudentId = widget.studentId ?? (students.isNotEmpty ? students.first['id'] : null);
        selectedCourseId = widget.courseId ?? (courses.isNotEmpty ? courses.first['id'] : null);
        coursePrice = _priceForCourse(selectedCourseId);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedStudentId == null || selectedCourseId == null || selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a student, course and payment method.')),
      );
      return;
    }

    // Checkout is intentionally a UI prototype. Do not write payment data,
    // activate a subscription, or grant points from the client.
    setState(() => submitting = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.construction_outlined, color: Theme.of(context).colorScheme.primary, size: 38),
        title: Text(fypTranslate(dialogContext, 'checkout_preview', 'Checkout preview')),
        content: Text(
          'The checkout screen is ready for review, but payment processing is currently disabled. '
          'No transfer has been submitted, no subscription has been activated, and no points have been granted.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(fypTranslate(dialogContext, 'got_it', 'Understood')),
          ),
        ],
      ),
    );
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(fypTranslate(context, 'subscription_access', 'Course subscription checkout')),
        
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go(FypRoutes.parent),
        ),
      ),
      body: SafeArea(
        child: loading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      elevation: 4,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFE2E8EF)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payment, size: 32, color: Theme.of(context).colorScheme.primary),
                                  SizedBox(width: 12),
                                  Text(
                                    fypTranslate(context, 'egyptian_payment_gateway', 'Egyptian payment options'),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Divider(),
                              SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedStudentId,
                                decoration: InputDecoration(
                                  labelText: fypTranslate(context, 'select_student_child', 'Select student'),
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                items: students.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s['id']?.toString(),
                                    child: Text(s['displayName'] ?? s['email'] ?? 'Student'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => selectedStudentId = val),
                                validator: (val) => val == null ? 'Please select a student' : null,
                              ),
                              SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedCourseId,
                                decoration: InputDecoration(
                                  labelText: fypTranslate(context, 'select_course', 'Select course'),
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                                items: courses.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['id']?.toString(),
                                    child: Text(c['title'] ?? 'Course'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() {
                                  selectedCourseId = val;
                                  coursePrice = _priceForCourse(val);
                                }),
                                validator: (val) => val == null ? 'Please select a course' : null,
                              ),
                              SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(fypTranslate(context, 'total_amount', 'Total amount'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('$coursePrice EGP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(fypTranslate(context, 'select_payment_method', 'Select Payment Method'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
                              SizedBox(height: 12),
                              RadioListTile<String>(
                                title: Text('InstaPay (National Bank / App Transfer)'),
                                subtitle: Text('Illustrative account details — to be configured'),
                                value: 'instapay',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              RadioListTile<String>(
                                title: Text('Vodafone Cash'),
                                subtitle: Text('Illustrative wallet details — to be configured'),
                                value: 'vodafone_cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              RadioListTile<String>(
                                title: Text('Orange Cash'),
                                subtitle: Text('Illustrative wallet details — to be configured'),
                                value: 'orange_cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              RadioListTile<String>(
                                title: Text('Etisalat Cash'),
                                subtitle: Text('Illustrative wallet details — to be configured'),
                                value: 'etisalat_cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: _referenceCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Transaction Reference / Sender Mobile No.',
                                  hintText: 'e.g. TRX12345678 or 010xxxxxxxx',
                                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Reference number is required.';
                                  return null;
                                },
                              ),
                              SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: submitting ? null : _processPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: submitting
                                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(fypTranslate(context, 'preview_checkout_disabled', 'Preview checkout (payments disabled)'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
