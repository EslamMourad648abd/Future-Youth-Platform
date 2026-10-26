import 'package:flutter/material.dart';

import '../core/theme/brand_colors.dart';

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
    this.primaryColor = BrandColors.navy,
  });

  static PlatformConfig current = futureYouth;

  static const PlatformConfig futureYouth = PlatformConfig(
    type: PlatformType.futureYouth,
    title: 'Future Youth Platform',
    subtitle: 'Learning platform for students, parents and teachers.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['admin', 'teacher', 'parent', 'student'],
    landingRoute: '/training',
    primaryColor: BrandColors.navy,
  );

  bool isRoleAllowed(String role) => allowedRoles.contains(role);
}
