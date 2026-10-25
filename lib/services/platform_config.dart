import 'package:flutter/material.dart';

enum PlatformType { futureYouth }

class PlatformConfig {
  final PlatformType type;
  final String title;
  final String subtitle;
  final String logoAsset;
  final List<String> allowedRoles;
  final String landingRoute;
  final Color primaryColor;

  const PlatformConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.logoAsset,
    required this.allowedRoles,
    required this.landingRoute,
    this.primaryColor = const Color(0xFF0284C7),
  });

  static PlatformConfig current = futureYouth;

  static const PlatformConfig futureYouth = PlatformConfig(
    type: PlatformType.futureYouth,
    title: 'Future Youth Platform',
    subtitle: 'Learning and development portal.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['admin', 'teacher', 'parent', 'student', 'superadmin', 'trainee'],
    landingRoute: '/future-youth',
    primaryColor: Color(0xFF263778),
  );

  bool isRoleAllowed(String role) => true;

  bool get isStandalone => false;
}
