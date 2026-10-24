import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
  // ============================================================
  // CURRENT ROLE
  // ============================================================

  static String role = "trainee";

  // ============================================================
  // LOAD USER ROLE
  // ============================================================

  static Future<void> loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      role = "trainee";
      return;
    }

    final email = user.email?.trim().toLowerCase() ?? "";
    if (email == "eslammourad2000@yahoo.com") {
      role = "superadmin";
      debugPrint("Loaded role: $role for primary admin $email");
      return;
    }

    try {
      final token = await user.getIdTokenResult(true);
      debugPrint("Token claims: ${token.claims}");

      final claimRole = token.claims?['role'];
      final isSuperAdminClaim = token.claims?['superadmin'] == true;

      if (claimRole is String && claimRole.isNotEmpty) {
        role = claimRole;
      } else if (isSuperAdminClaim) {
        role = "superadmin";
      } else {
        // Fallback to Firestore user document
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (doc.exists) {
          final firestoreRole = doc.data()?['role'];
          if (firestoreRole is String && firestoreRole.isNotEmpty) {
            role = firestoreRole;
          } else {
            role = "trainee";
          }
        } else {
          role = "trainee";
        }
      }
    } catch (e) {
      debugPrint("Error reading token claims: $e");
      try {
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (doc.exists && doc.data()?['role'] is String) {
          role = doc.data()!['role'];
        } else {
          role = "trainee";
        }
      } catch (docErr) {
        debugPrint("Error fallback reading user doc: $docErr");
        role = "trainee";
      }
    }

    debugPrint("Loaded role: $role");
  }

  // ============================================================
  // ROLE CHECKS
  // ============================================================

  static bool get isSuperAdmin {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? "";
    return role == "superadmin" || email == "eslammourad2000@yahoo.com";
  }

  static bool get isOnboardingAgent => role == "onboarding_agent";

  static bool get isSupportAgent => role == "support_agent";

  static bool get isTrainee => role == "trainee";

  static bool get isAgent => isOnboardingAgent || isSupportAgent;
}
