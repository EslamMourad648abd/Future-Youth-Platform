import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import 'learning_workflow_screen.dart';

const Color futureYouthNavy = Color(0xFF263778);
const Color futureYouthGreen = Color(0xFF00A651);

class FutureYouthHome extends StatelessWidget {
  const FutureYouthHome({super.key});

  @override
  Widget build(BuildContext context) {
    final role = AuthService.role.toLowerCase();
    final user = FirebaseAuth.instance.currentUser;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'منصة مستقبل الشباب' : 'Future Youth Platform';
    final greeting = isArabic ? 'أهلاً بك' : 'Welcome';
    final roleName = _roleName(role, isArabic);
    final actions = _actionsFor(role, isArabic);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: futureYouthNavy,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 34, height: 34,
              errorBuilder: (_, __, ___) => const Icon(Icons.school_outlined)),
            const SizedBox(width: 10),
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isArabic ? 'تغيير اللغة' : 'Switch language',
            onPressed: AppLocalizations.toggleLocale,
            icon: const Icon(Icons.language),
          ),
          IconButton(
            tooltip: isArabic ? 'تسجيل الخروج' : 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [futureYouthNavy, Color(0xFF4057A7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(user?.displayName?.trim().isNotEmpty == true
                          ? user!.displayName!
                          : (user?.email ?? roleName),
                        style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(roleName, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 18),
                      Text(isArabic
                          ? 'مكان واحد للتعلّم وإدارة المحتوى ومتابعة التقدم.'
                          : 'One place to learn, manage lessons, and track progress.',
                        style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(isArabic ? 'مساحة العمل الخاصة بك' : 'Your workspace',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: futureYouthNavy)),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth > 850 ? 3 : (constraints.maxWidth > 540 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: actions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: columns == 1 ? 3.3 : 1.55,
                    ),
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      return _WorkspaceCard(
                        icon: action.icon,
                        title: action.title,
                        description: action.description,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => LearningWorkflowScreen(
                            kind: action.kind,
                            title: action.title,
                          ),
                        )),
                      );
                    },
                  );
                }),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E7F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: futureYouthGreen, size: 30),
                        const SizedBox(width: 14),
                        Expanded(child: Text(isArabic
                          ? 'المحتوى المدفوع متاح بعد تأكيد الدفع وموافقة الإدارة على المحتوى. تظل المعاينة المجانية متاحة.'
                          : 'Paid lessons unlock after payment confirmation and admin content approval. The designated free preview remains available.',
                          style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _roleName(String role, bool ar) {
    switch (role) {
      case 'admin':
      case 'superadmin':
        return ar ? 'الإدارة' : 'Administrator';
      case 'teacher':
        return ar ? 'المعلم' : 'Teacher';
      case 'parent':
        return ar ? 'ولي الأمر' : 'Parent';
      case 'student':
      case 'trainee':
        return ar ? 'الطالب' : 'Student';
      default:
        return ar ? 'المستخدم' : 'User';
    }
  }

  static List<_WorkspaceAction> _actionsFor(String role, bool ar) {
    if (role == 'admin' || role == 'superadmin') {
      return [
        _WorkspaceAction(Icons.fact_check_outlined, ar ? 'مراجعة المحتوى' : 'Content review',
          ar ? 'راجع الفيديوهات ووافق عليها أو ارفضها.' : 'Review submitted videos and approve or reject them.', 'admin_review'),
        _WorkspaceAction(Icons.people_outline, ar ? 'إدارة المعلمين' : 'Teacher management',
          ar ? 'تابع طلبات المعلمين وحالة الموافقة.' : 'Review teacher profiles and approval status.', 'teacher_management'),
        _WorkspaceAction(Icons.payments_outlined, ar ? 'طلبات الدفع' : 'Payment requests',
          ar ? 'راجع الطلبات وسجّل قرار التحقق.' : 'Review payment requests and record verification.', 'payments'),
        _WorkspaceAction(Icons.analytics_outlined, ar ? 'تقارير المنصة' : 'Platform overview',
          ar ? 'عرض ملخصات المحتوى والتعلّم.' : 'View high-level learning and content summaries.', 'admin_overview'),
      ];
    }
    if (role == 'teacher') {
      return [
        _WorkspaceAction(Icons.badge_outlined, ar ? 'ملفي كمعلم' : 'Teacher profile',
          ar ? 'قدّم ملفك لمراجعة الإدارة.' : 'Submit your teacher profile for Admin approval.', 'teacher_profile'),
        _WorkspaceAction(Icons.video_library_outlined, ar ? 'محتواي' : 'My content',
          ar ? 'أنشئ قوائم التشغيل والوحدات والدروس والفيديوهات.' : 'Create playlists, units, lessons, and video entries.', 'teacher_content'),
        _WorkspaceAction(Icons.upload_file_outlined, ar ? 'إرسال فيديو للمراجعة' : 'Submit a video',
          ar ? 'أرسل بيانات الفيديو لمراجعة الإدارة.' : 'Submit video metadata for Admin review.', 'teacher_video'),
        _WorkspaceAction(Icons.rate_review_outlined, ar ? 'تقارير المراجعة' : 'Review reports',
          ar ? 'تابع حالة المراجعة وملاحظات الإدارة.' : 'Track review status and admin feedback.', 'teacher_reports'),
        _WorkspaceAction(Icons.insights_outlined, ar ? 'تحليلات المحتوى' : 'Content analytics',
          ar ? 'المشاهدات والتقييمات والتعليقات لمحتواك.' : 'Views, ratings, and comments for your content.', 'teacher_analytics'),
      ];
    }
    if (role == 'parent') {
      return [
        _WorkspaceAction(Icons.family_restroom_outlined, ar ? 'أبنائي' : 'My children',
          ar ? 'إدارة ملفات الأبناء وطلبات الدعوة.' : 'Manage child profiles and invitation requests.', 'parent_children'),
        _WorkspaceAction(Icons.payment_outlined, ar ? 'الاشتراكات والدفع' : 'Subscriptions & payments',
          ar ? 'اختر طريقة الدفع وتابع حالة الطلب.' : 'Choose a payment method and track requests.', 'payments'),
        _WorkspaceAction(Icons.query_stats_outlined, ar ? 'تقدم الأبناء' : 'Children progress',
          ar ? 'تابع النتائج ووقت المشاهدة والتقدم.' : 'Track results, watch time, and progress.', 'parent_progress'),
      ];
    }
    return [
      _WorkspaceAction(Icons.search_outlined, ar ? 'اكتشف المعلمين' : 'Explore teachers',
        ar ? 'استعرض المعلمين المعتمدين واختر معلمًا لكل مادة.' : 'Browse approved teachers and select one for each subject.', 'student_catalog'),
      _WorkspaceAction(Icons.ondemand_video_outlined, ar ? 'المعاينات المجانية' : 'Free previews',
        ar ? 'شاهد الفيديوهات المجانية المعتمدة.' : 'Watch approved designated free-preview videos.', 'student_previews'),
      _WorkspaceAction(Icons.play_circle_outline, ar ? 'تعلمي' : 'My learning',
        ar ? 'تابع الدروس والاشتراكات ونقاط المشاهدة.' : 'Continue lessons, subscriptions, and viewing points.', 'student_learning'),
      _WorkspaceAction(Icons.assignment_outlined, ar ? 'الاختبارات والنتائج' : 'Exams & results',
        ar ? 'اعرض اختبارات الدروس والوحدات ونتائجك.' : 'Access lesson/unit exams and your results.', 'student_exams'),
    ];
  }
}

class _WorkspaceAction {
  const _WorkspaceAction(this.icon, this.title, this.description, this.kind);
  final IconData icon;
  final String title;
  final String description;
  final String kind;
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.icon, required this.title, required this.description, required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E7F0)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: futureYouthGreen, size: 29),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: futureYouthNavy)),
            const SizedBox(height: 6),
            Expanded(child: Text(description, style: const TextStyle(color: Color(0xFF626B7A), height: 1.35))),
          ]),
        ),
      ),
    );
  }
}
