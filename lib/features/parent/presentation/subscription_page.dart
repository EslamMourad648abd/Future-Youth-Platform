import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/fyp_routes.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/brand_colors.dart';

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
          .get();

      final courseList = courseSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      if (!mounted) return;
      setState(() {
        students = studentList;
        courses = courseList;
        selectedStudentId = widget.studentId ?? (students.isNotEmpty ? students.first['id'] : null);
        selectedCourseId = widget.courseId ?? (courses.isNotEmpty ? courses.first['id'] : null);
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
    if (selectedStudentId == null || selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both a student and a course.'),
          backgroundColor: BrandColors.error,
        ),
      );
      return;
    }

    setState(() {
      submitting = true;
    });

    final parentUser = FirebaseAuth.instance.currentUser;

    try {
      final paymentRef = await FirebaseFirestore.instance.collection(FirestorePaths.payments).add({
        'parentId': parentUser?.uid,
        'studentId': selectedStudentId,
        'courseId': selectedCourseId,
        'amount': coursePrice,
        'currency': 'EGP',
        'paymentMethod': selectedPaymentMethod,
        'referenceNumber': _referenceCtrl.text.trim(),
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection(FirestorePaths.subscriptions).add({
        'parentId': parentUser?.uid,
        'studentId': selectedStudentId,
        'courseId': selectedCourseId,
        'paymentId': paymentRef.id,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (widget.invoiceId != null && widget.invoiceId!.isNotEmpty) {
        await FirebaseFirestore.instance.collection('invoices').doc(widget.invoiceId).update({
          'status': 'paid',
          'paymentMethod': selectedPaymentMethod,
          'paidAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment processed successfully! Subscription is active.'),
          backgroundColor: BrandColors.greenText,
        ),
      );

      context.go(FypRoutes.parent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: BrandColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        title: const Text('Course Subscription Checkout'),
        backgroundColor: BrandColors.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(FypRoutes.parent),
        ),
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      elevation: 4,
                      color: Colors.white,
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
                              const Row(
                                children: [
                                  Icon(Icons.payment, size: 32, color: BrandColors.navy),
                                  SizedBox(width: 12),
                                  Text(
                                    'Egyptian Payment Gateway',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BrandColors.navy),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedStudentId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Student Child',
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
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedCourseId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Course / Teacher Playlist',
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                                items: courses.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['id']?.toString(),
                                    child: Text(c['title'] ?? 'Course'),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => selectedCourseId = val),
                                validator: (val) => val == null ? 'Please select a course' : null,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: BrandColors.navyTint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('$coursePrice EGP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: BrandColors.navy)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BrandColors.navy)),
                              const SizedBox(height: 12),
                              RadioListTile<String>(
                                title: const Text('InstaPay (National Bank / App Transfer)'),
                                subtitle: const Text('Transfer to InstaPay IPA: futureyouth@instapay'),
                                value: 'instapay',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              RadioListTile<String>(
                                title: const Text('Vodafone Cash'),
                                subtitle: const Text('Transfer to Wallet: 01012345678'),
                                value: 'vodafone_cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              RadioListTile<String>(
                                title: const Text('Orange Cash'),
                                subtitle: const Text('Transfer to Wallet: 01212345678'),
                                value: 'orange_cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              RadioListTile<String>(
                                title: const Text('Etisalat Cash'),
                                subtitle: const Text('Transfer to Wallet: 01112345678'),
                                value: 'etisalat_cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (val) => setState(() => selectedPaymentMethod = val),
                                activeColor: BrandColors.navy,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _referenceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Transaction Reference / Sender Mobile No.',
                                  hintText: 'e.g. TRX12345678 or 010xxxxxxxx',
                                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Reference number is required.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: submitting ? null : _processPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: submitting
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Confirm Payment & Subscribe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
