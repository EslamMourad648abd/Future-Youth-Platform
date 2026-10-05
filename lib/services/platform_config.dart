import 'package:flutter/material.dart';

enum PlatformType { support, onboarding, trainee, apiTool, master }

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
    this.primaryColor = const Color(0xFF38BDF8),
  });

  static PlatformConfig current = master;

  static const PlatformConfig master = PlatformConfig(
    type: PlatformType.master,
    title: 'BBC Operations Platform',
    subtitle: 'Master control and combined dashboards.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['superadmin', 'onboarding_agent', 'support_agent', 'trainee', 'agent'],
    landingRoute: '/home',
  );

  static const PlatformConfig support = PlatformConfig(
    type: PlatformType.support,
    title: 'BBC Support Platform',
    subtitle: 'Dedicated workspace for support operations.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['superadmin', 'support_agent', 'agent'],
    landingRoute: '/operations/onboarding/clients',
    primaryColor: Color(0xFF00C853), // Example: slightly different color for Support
  );

  static const PlatformConfig onboarding = PlatformConfig(
    type: PlatformType.onboarding,
    title: 'BBC Onboarding Platform',
    subtitle: 'Manage client activations and verified status.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['superadmin', 'onboarding_agent'],
    landingRoute: '/operations/onboarding',
  );

  static const PlatformConfig trainee = PlatformConfig(
    type: PlatformType.trainee,
    title: 'BEVATEL Training Portal',
    subtitle: 'Learning and development resources.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['superadmin', 'trainee'],
    landingRoute: '/training',
    primaryColor: Color(0xFF6200EA), // Deep purple for learning
  );

  static const PlatformConfig apiTool = PlatformConfig(
    type: PlatformType.apiTool,
    title: 'BBC API Tool',
    subtitle: 'Internal API testing and documentation.',
    logoAsset: 'assets/logo.png',
    allowedRoles: ['superadmin', 'onboarding_agent', 'support_agent', 'trainee', 'agent'],
    landingRoute: '/bbc-api',
    primaryColor: Color(0xFFFF6D00), // Orange for API tool
  );

  bool isRoleAllowed(String role) {
    if (type == PlatformType.master) return true;
    return allowedRoles.contains(role);
  }

  bool get isStandalone => type != PlatformType.master;
}
