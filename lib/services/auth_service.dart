import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
  // ============================================================
  // ROLES CONSTANTS
  // ============================================================

  static const String adminRole = "admin";
  static const String superAdminRole = "superadmin";
  static const String teacherRole = "teacher";
  static const String parentRole = "parent";
  static const String studentRole = "student";

  // ============================================================
  // CURRENT ROLE
  // ============================================================

  static String role = studentRole;

  // ============================================================
  // LOAD USER ROLE
  // ============================================================

  static Future<void> loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      role = studentRole;
      return;
    }

    final email = user.email?.trim().toLowerCase() ?? "";
    if (email == "eslammourad2000@yahoo.com") {
      role = adminRole;
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
        role = adminRole;
      } else {
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (doc.exists) {
          final firestoreRole = doc.data()?['role'];
          if (firestoreRole is String && firestoreRole.isNotEmpty) {
            role = firestoreRole;
          } else {
            role = studentRole;
          }
        } else {
          role = studentRole;
        }
      }
    } catch (e) {
      debugPrint("Error reading token claims: $e");
      try {
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (doc.exists && doc.data()?['role'] is String) {
          role = doc.data()!['role'];
        } else {
          role = studentRole;
        }
      } catch (docErr) {
        debugPrint("Error fallback reading user doc: $docErr");
        role = studentRole;
      }
    }

    debugPrint("Loaded role: $role");
  }

  // ============================================================
  // ROLE CHECKS
  // ============================================================

  static bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? "";
    return role == adminRole || role == superAdminRole || email == "eslammourad2000@yahoo.com";
  }

  static bool get isSuperAdmin => isAdmin;

  static bool get isTeacher => role == teacherRole;

  static bool get isParent => role == parentRole;

  static bool get isStudent => role == studentRole || role == "trainee";
}
