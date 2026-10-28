import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/user_role.dart';

class AuthController extends ChangeNotifier {
  User? _user;
  UserRole? _role;
  bool _initialized = false;

  StreamSubscription<User?>? _subscription;

  AuthController() {
    _init();
  }

  bool get signedIn => _user != null;
  UserRole? get role => _role;
  bool get initialized => _initialized;
  User? get currentUser => _user;

  void _init() {
    _user = FirebaseAuth.instance.currentUser;
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      _user = user;
      if (user == null) {
        _role = null;
        _initialized = true;
        notifyListeners();
      } else {
        await reloadRole();
      }
    });

    if (_user != null) {
      reloadRole();
    } else {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> reloadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    _user = user;

    if (user == null) {
      _role = null;
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      final tokenResult = await user.getIdTokenResult(true);
      final claimRoleStr = tokenResult.claims?['role']?.toString();
      final isSuperAdminClaim = tokenResult.claims?['superadmin'] == true;

      if (isSuperAdminClaim || claimRoleStr == "superadmin" || claimRoleStr == "admin") {
        _role = UserRole.admin;
      } else if (claimRoleStr != null) {
        _role = UserRole.tryParse(claimRoleStr) ?? _mapLegacyRole(claimRoleStr);
      }

      if (_role == null) {
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (doc.exists) {
          final firestoreRole = doc.data()?['role']?.toString();
          if (firestoreRole != null) {
            _role = UserRole.tryParse(firestoreRole) ?? _mapLegacyRole(firestoreRole);
          }
        }
      }
    } catch (e) {
      debugPrint("AuthController reloadRole error: $e");
    }

    _role ??= UserRole.student;
    _initialized = true;
    notifyListeners();
  }

  UserRole _mapLegacyRole(String roleStr) {
    final lower = roleStr.toLowerCase().trim();
    if (lower == "superadmin" || lower == "admin") return UserRole.admin;
    if (lower == "teacher") return UserRole.teacher;
    if (lower == "parent") return UserRole.parent;
    return UserRole.student;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
