import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
  // ============================================================
  // ROLES CONSTANTS
  // ============================================================

  static const String adminRole = "admin";
  static const String superAdminRole = "admin";
  static const String teacherRole = "teacher";
  static const String parentRole = "parent";
  static const String studentRole = "student";

  // ============================================================
  // CURRENT ROLE
  // ============================================================

  static String role = studentRole;

  static String normalizeRole(String? value) {
    switch ((value ?? "").trim().toLowerCase()) {
      case "admin":
      case "superadmin":
        return adminRole;
      case "teacher":
        return teacherRole;
      case "parent":
        return parentRole;
      case "student":
      case "trainee":
        return studentRole;
      default:
        return "";
    }
  }

  // ============================================================
  // LOAD USER ROLE
  // ============================================================

  static Future<void> loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      role = studentRole;
      return;
    }

    try {
      final token = await user.getIdTokenResult(true);
      debugPrint("Token claims: ${token.claims}");

      final claimRole = normalizeRole(token.claims?['role']?.toString());
      final isAdminClaim = token.claims?['superadmin'] == true;

      if (claimRole.isNotEmpty) {
        role = claimRole;
      } else if (isAdminClaim) {
        role = adminRole;
      } else {
        final doc =
            await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        final firestoreRole = normalizeRole(doc.data()?['role']?.toString());
        role = firestoreRole.isNotEmpty ? firestoreRole : studentRole;
      }
    } catch (e) {
      debugPrint("Error reading token claims: $e");
      try {
        final doc =
            await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        final firestoreRole = normalizeRole(doc.data()?['role']?.toString());
        role = firestoreRole.isNotEmpty ? firestoreRole : studentRole;
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

  static bool get isAdmin => role == adminRole;

  static bool get isSuperAdmin => isAdmin;

  static bool get isTeacher => role == teacherRole;

  static bool get isParent => role == parentRole;

  static bool get isStudent => role == studentRole;
}
