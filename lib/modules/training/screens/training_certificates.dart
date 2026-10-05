import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/certificate_model.dart';
import '../services/certificate_service.dart';

class TrainingCertificates extends StatefulWidget {
  const TrainingCertificates({
    super.key,
  });

  @override
  State<TrainingCertificates> createState() =>
      _TrainingCertificatesState();
}

class _TrainingCertificatesState
    extends State<TrainingCertificates> {
  // ============================================================
  // SERVICES
  // ============================================================

  final CertificateService _certificateService =
  CertificateService();

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;

  String? _errorMessage;

  List<CertificateModel> _certificates = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCertificates();
  }

  // ============================================================
  // LOAD CERTIFICATES
  // ============================================================

  Future<void> _loadCertificates() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _certificates = [];
        _errorMessage = null;
      });

      return;
    }

    try {
      // ==========================================================
      // IMPORTANT
      //
      // Certificates are stored in:
      //
      // /certificates
      //
      // NOT:
      //
      // /users/{uid}/certificates
      //
      // We only filter by userId here.
      //
      // We intentionally DO NOT use orderBy('issuedAt') in the
      // Firestore query because that creates a composite-index
      // requirement together with userId.
      // ==========================================================

      final snapshot =
      await FirebaseFirestore.instance
          .collection('certificates')
          .where(
        'userId',
        isEqualTo: user.uid,
      )
          .get(
        const GetOptions(
          source: Source.server,
        ),
      );

      final certificates = snapshot.docs
          .map(
            (doc) => _certificateFromFirestore(
          doc,
        ),
      )
          .toList();

      // ==========================================================
      // SORT LOCALLY
      // ==========================================================

      certificates.sort(
            (a, b) => b.issuedAt.compareTo(
          a.issuedAt,
        ),
      );

      if (!mounted) return;

      setState(() {
        _certificates = certificates;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'TRAINING CERTIFICATES ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _certificates = [];
        _errorMessage =
        'Failed to load your certificates.';
      });
    }
  }

  // ============================================================
  // FIRESTORE -> MODEL
  // ============================================================

  CertificateModel _certificateFromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    final issuedAt = _parseDate(
      data['issuedAt'],
    );

    return CertificateModel(
      id: doc.id,
      userId: _stringValue(
        data['userId'],
      ),
      courseId: _stringValue(
        data['courseId'],
      ),
      traineeName: _stringValue(
        data['traineeName'],
      ),
      courseName: _stringValue(
        data['courseTitle'],
      ),
      issuedAt: issuedAt,
      storagePath: _stringValue(
        data['storagePath'],
      ),
      downloadUrl: _stringValue(
        data['certificateUrl'],
      ),
    );
  }

  // ============================================================
  // STRING
  // ============================================================

  String _stringValue(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime _parseDate(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(
        value,
      );

      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.now();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    if (_loading) {
      return const _CertificatesLoading();
    }

    if (_errorMessage != null) {
      return _CertificatesError(
        message: _errorMessage!,
        onRetry: _loadCertificates,
      );
    }

    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        physics:
        const BouncingScrollPhysics(),
        padding:
        const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 1400,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildHeader(context),

                const SizedBox(
                  height: 28,
                ),

                if (_certificates.isEmpty)
                  const _EmptyCertificates()
                else
                  _buildCertificates(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 650;

      final headerContent = [
        Expanded(
          flex: isCompact ? 0 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Certificates',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View and access the certificates you have earned.',
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        if (isCompact) const SizedBox(height: 16) else const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                '${_certificates.length} '
                '${_certificates.length == 1 ? 'Certificate' : 'Certificates'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ];

      return isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: headerContent,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: headerContent,
            );
    });
  }

  // ============================================================
  // CERTIFICATES GRID
  // ============================================================

  Widget _buildCertificates() {
    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        int columns;

        if (constraints.maxWidth >=
            1100) {
          columns = 3;
        } else if (constraints.maxWidth >=
            700) {
          columns = 2;
        } else {
          columns = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics:
          const NeverScrollableScrollPhysics(),
          itemCount:
          _certificates.length,
          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
            columns,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: 290,
          ),
          itemBuilder:
              (
              context,
              index,
              ) {
            return _CertificateCard(
              certificate:
              _certificates[index],
              onView: () {
                _openCertificate(
                  context,
                  _certificates[index],
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // OPEN CERTIFICATE
  // ============================================================

  Future<void> _openCertificate(
      BuildContext context,
      CertificateModel certificate,
      ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
          dialogContext,
          ) {
        return _CertificateDialog(
          certificate: certificate,
          certificateService:
          _certificateService,
        );
      },
    );
  }
}

// ============================================================
// CERTIFICATE CARD
// ============================================================

class _CertificateCard
    extends StatelessWidget {
  final CertificateModel certificate;

  final VoidCallback onView;

  const _CertificateCard({
    required this.certificate,
    required this.onView,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      padding:
      const EdgeInsets.all(22),
      decoration:
      BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ======================================================
          // ICON
          // ======================================================

          Container(
            width: 54,
            height: 54,
            decoration:
            BoxDecoration(
              color:
              theme.colorScheme.primary
                  .withValues(alpha: 0.07),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium,
              color:
              theme.colorScheme.primary,
              size: 29,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          // ======================================================
          // COURSE
          // ======================================================

          Text(
            certificate.courseName.isEmpty
                ? 'Training Certificate'
                : certificate.courseName,
            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,
            style:
            TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.w700,
              color:
              theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // ======================================================
          // TRAINEE
          // ======================================================

          Text(
            certificate.traineeName.isEmpty
                ? 'Certificate holder'
                : certificate.traineeName,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style:
            TextStyle(
              fontSize: 13,
              color:
              theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const Spacer(),

          // ======================================================
          // DATE
          // ======================================================

          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color:
                theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(
                width: 7,
              ),
              Text(
                _formatDate(
                  certificate.issuedAt,
                ),
                style:
                TextStyle(
                  fontSize: 12,
                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          // ======================================================
          // VIEW
          // ======================================================

          SizedBox(
            width:
            double.infinity,
            child:
            ElevatedButton.icon(
              onPressed: onView,
              icon: const Icon(
                Icons.visibility_outlined,
                size: 18,
              ),
              label:
              const Text(
                'View Certificate',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                theme.colorScheme.primary,
                foregroundColor:
                theme.colorScheme.onPrimary,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    9,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
      DateTime date,
      ) {
    final day =
    date.day.toString().padLeft(
      2,
      '0',
    );

    final month =
    date.month.toString().padLeft(
      2,
      '0',
    );

    return '$day/$month/${date.year}';
  }
}

// ============================================================
// CERTIFICATE DIALOG
//
// Same certificate-loading implementation as CourseDetails.
// ============================================================

class _CertificateDialog
    extends StatefulWidget {
  final CertificateModel certificate;

  final CertificateService
  certificateService;

  const _CertificateDialog({
    required this.certificate,
    required this.certificateService,
  });

  @override
  State<_CertificateDialog> createState() =>
      _CertificateDialogState();
}

class _CertificateDialogState
    extends State<_CertificateDialog> {
  // ============================================================
  // STATE
  // ============================================================

  String? certificateUrl;

  String? certificateViewType;

  bool generating = true;

  String? error;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _generateCertificate();
  }

  // ============================================================
  // GENERATE / LOAD CERTIFICATE
  //
  // IMPORTANT:
  //
  // We intentionally do NOT use:
  //
  // widget.certificate.downloadUrl
  //
  // The same CertificateService flow used by CourseDetails is
  // used here.
  // ============================================================

  Future<void> _generateCertificate() async {
    try {
      final courseId =
          widget.certificate.courseId;

      if (courseId.isEmpty) {
        throw Exception(
          'Certificate course ID is not available.',
        );
      }

      final url =
      await widget.certificateService
          .generateCertificate(
        courseId: courseId,
      );

      if (!mounted) return;

      if (url.isEmpty) {
        throw Exception(
          'Certificate URL is not available.',
        );
      }

      // ==========================================================
      // CREATE UNIQUE VIEW TYPE
      // ==========================================================

      final viewType =
          'certificate-pdf-${DateTime.now().microsecondsSinceEpoch}';

      // ==========================================================
      // CREATE IFRAME
      // ==========================================================

      final iframe =
      html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.outline = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor =
            'white'
        ..allowFullscreen = true;

      // ==========================================================
      // REGISTER FLUTTER WEB VIEW
      // ==========================================================

      ui_web.platformViewRegistry
          .registerViewFactory(
        viewType,
            (int viewId) => iframe,
      );

      if (!mounted) return;

      setState(() {
        certificateUrl = url;
        certificateViewType =
            viewType;
        generating = false;
        error = null;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'CERTIFICATE BOARD POPUP ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        generating = false;
        error = e.toString();
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor:
      theme.cardTheme.color,
      surfaceTintColor:
      theme.cardTheme.color,
      elevation: 12,
      insetPadding:
      const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(24),
      ),
      child: SizedBox(
        width:
        MediaQuery.of(context)
            .size
            .width
            .clamp(
          320.0,
          1000.0,
        ),
        height:
        MediaQuery.of(context)
            .size
            .height
            .clamp(
          500.0,
          900.0,
        ) *
            0.88,
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                24,
                20,
                16,
                14,
              ),
              child: Row(
                children: [
                  _buildHeaderIcon(context),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          'Certificate',
                          style:
                          TextStyle(
                            fontSize: 23,
                            fontWeight:
                            FontWeight
                                .w700,
                            color:
                            theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          widget
                              .certificate
                              .courseName
                              .isEmpty
                              ? 'Training Certificate'
                              : widget
                              .certificate
                              .courseName,
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          TextStyle(
                            fontSize: 14,
                            color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // X
                  //
                  // EXACT BEHAVIOR:
                  // Disabled while generating.
                  // ==================================================

                  IconButton(
                    onPressed: generating
                        ? null
                        : () {
                      if (!mounted) {
                        return;
                      }

                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon:
                    Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
                    ),
                    tooltip:
                    generating
                        ? 'Preparing certificate'
                        : 'Close',
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: theme.dividerColor,
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  0,
                ),
                child: Column(
                  children: [
                    // ==================================================
                    // STATUS
                    // ==================================================

                    Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            generating
                                ? Icons
                                .hourglass_top
                                : Icons
                                .verified,
                            size: 20,
                            color:
                            theme.colorScheme.primary,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              generating
                                  ? 'Your certificate is being prepared...'
                                  : error != null
                                  ? 'Unable to load your certificate.'
                                  : 'Your certificate is ready.',
                              style:
                              TextStyle(
                                fontSize: 14,
                                color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // CERTIFICATE AREA
                    // ==================================================

                    Expanded(
                      child:
                      _buildCertificateArea(context),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // CLOSE BUTTON
                    // ==================================================

                    Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: SizedBox(
                        width:
                        double.infinity,
                        height: 46,
                        child:
                        OutlinedButton(
                          onPressed:
                          generating
                              ? null
                              : () {
                            if (!mounted) {
                              return;
                            }

                            Navigator.of(
                              context,
                            ).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.dividerColor),
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                          child:
                          const Text(
                            'Close',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER ICON
  // ============================================================

  Widget _buildHeaderIcon(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 54,
      height: 54,
      decoration:
      BoxDecoration(
        color:
        theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.workspace_premium,
        size: 32,
        color:
        theme.colorScheme.primary,
      ),
    );
  }

  // ============================================================
  // CERTIFICATE AREA
  // ============================================================

  Widget _buildCertificateArea(BuildContext context) {
    final theme = Theme.of(context);
    // ==========================================================
    // GENERATING
    // ==========================================================

    if (generating) {
      return Container(
        width:
        double.infinity,
        decoration:
        BoxDecoration(
          color:
          theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color:
            theme.dividerColor,
          ),
        ),
        child:
        Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child:
                CircularProgressIndicator(
                  color:
                  theme.colorScheme.primary,
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Text(
                'Preparing your certificate',
                style:
                TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  theme.colorScheme.primary,
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Text(
                'Please wait...',
                style:
                TextStyle(
                  fontSize: 13,
                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (error != null) {
      return Container(
        width:
        double.infinity,
        decoration:
        BoxDecoration(
          color:
          Colors.red.withValues(alpha: 0.05),
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color:
            Colors.red.withValues(alpha: 0.2),
          ),
        ),
        child:
        Center(
          child: Padding(
            padding:
            const EdgeInsets.all(
              30,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color:
                  Colors.red,
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Unable to load certificate',
                  style:
                  TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  'Please close this window and try again.',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    fontSize: 13,
                    color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================================
    // PDF
    // ==========================================================

    if (certificateUrl != null &&
        certificateViewType != null) {
      return ClipRRect(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        child: Container(
          width:
          double.infinity,
          color: Colors.white,
          child:
          HtmlElementView(
            viewType:
            certificateViewType!,
          ),
        ),
      );
    }

    return const SizedBox();
  }
}

// ============================================================
// EMPTY
// ============================================================

class _EmptyCertificates
    extends StatelessWidget {
  const _EmptyCertificates();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        constraints:
        const BoxConstraints(
          maxWidth: 500,
        ),
        padding:
        const EdgeInsets.all(42),
        decoration:
        BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius:
          BorderRadius.circular(18),
          border: Border.all(
            color:
            theme.dividerColor,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
              BoxDecoration(
                color:
                theme.colorScheme.primary.withValues(
                  alpha: 0.07,
                ),
                shape:
                BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .workspace_premium_outlined,
                size: 36,
                color:
                theme.colorScheme.primary,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              'No Certificates Yet',
              style:
              TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.w700,
                color:
                theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Complete a training course to earn your certificate.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontSize: 13,
                color:
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _CertificatesLoading
    extends StatelessWidget {
  const _CertificatesLoading();

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      color:
      theme.colorScheme.surface,
      child:
      Center(
        child:
        CircularProgressIndicator(
          color:
          theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _CertificatesError
    extends StatelessWidget {
  final String message;

  final VoidCallback onRetry;

  const _CertificatesError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Container(
      color:
      theme.colorScheme.surface,
      child:
      Center(
        child: Container(
          constraints:
          const BoxConstraints(
            maxWidth: 500,
          ),
          padding:
          const EdgeInsets.all(32),
          margin:
          const EdgeInsets.all(24),
          decoration:
          BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius:
            BorderRadius.circular(16),
            border: Border.all(
              color:
              theme.dividerColor,
            ),
          ),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 42,
                color:
                Colors.redAccent,
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                'Unable to load certificates',
                style:
                TextStyle(
                  fontSize: 19,
                  fontWeight:
                  FontWeight.w700,
                  color:
                  theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                message,
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 13,
                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              ElevatedButton.icon(
                onPressed: onRetry,
                icon:
                const Icon(
                  Icons.refresh,
                  size: 18,
                ),
                label:
                const Text(
                  'Retry',
                ),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  theme.colorScheme.primary,
                  foregroundColor:
                  theme.colorScheme.onPrimary,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
