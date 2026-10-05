
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
// ============================================================
// CURRENT ROLE
// ============================================================

// Default role for users before their role is loaded.
//
// IMPORTANT:
// This does NOT assign a Firebase role.
// The actual role comes from the Firebase Auth custom claim.
static String role = "support_agent";

// ============================================================
// LOAD USER ROLE
// ============================================================

static Future<void> loadUserRole() async {
final user =
FirebaseAuth.instance.currentUser;

// ------------------------------------------------------------
// No authenticated user
// ------------------------------------------------------------

if (user == null) {
role = "support_agent";
return;
}

// ------------------------------------------------------------
// Get latest Firebase ID token claims
// ------------------------------------------------------------

final token =
await user.getIdTokenResult(true);

debugPrint(
"Token claims: ${token.claims}",
);

// ------------------------------------------------------------
// Read role
// ------------------------------------------------------------

final claimRole =
token.claims?['role'];

if (claimRole is String &&
claimRole.isNotEmpty) {
role = claimRole;
} else {
// ----------------------------------------------------------
// Legacy/default fallback
//
// Existing users may still have the old "agent" role until
// you manually migrate them from Super Admin > User
// Management.
//
// Treat legacy "agent" as support_agent on the client side.
// ----------------------------------------------------------

role = "support_agent";
}

debugPrint(
"Loaded role: $role",
);
}

// ============================================================
// ROLE CHECKS
// ============================================================

// ------------------------------------------------------------
// SUPER ADMIN
//
// Full platform access.
// ------------------------------------------------------------

static bool get isSuperAdmin =>
role == "superadmin";

// ------------------------------------------------------------
// ONBOARDING AGENT
//
// BBC API + Onboarding Platform.
// ------------------------------------------------------------

static bool get isOnboardingAgent =>
role == "onboarding_agent";

// ------------------------------------------------------------
// SUPPORT AGENT
//
// BBC API only.
// ------------------------------------------------------------

static bool get isSupportAgent =>
role == "support_agent";

// ------------------------------------------------------------
// TRAINEE
//
// BBC API + Training Portal.
//
// This role remains unchanged.
// ------------------------------------------------------------

static bool get isTrainee =>
role == "trainee";

// ============================================================
// LEGACY AGENT COMPATIBILITY
// ============================================================
//
// Keep this temporarily so existing screens/services that still
// reference AuthService.isAgent do not immediately fail.
//
// It represents either of the two new agent roles.
//
// New code should use:
//
//   AuthService.isOnboardingAgent
//
// or:
//
//   AuthService.isSupportAgent
//
// instead.
// ============================================================

static bool get isAgent =>
isOnboardingAgent ||
isSupportAgent;
}
