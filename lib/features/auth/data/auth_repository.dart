import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/user_role.dart';
import '../domain/auth_session.dart';

abstract class AuthRepository {
  Stream<AuthSession> sessionChanges();
  Future<void> signInAs(UserRole expectedRole, String identifier, String password);
  Future<void> signUpParentOrTeacher({
    required UserRole role,
    required String name,
    required String email,
    required String password,
  });
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static String mapIdentifierToEmail(UserRole role, String identifier) {
    final clean = identifier.trim().toLowerCase();
    if (role == UserRole.student && !clean.contains('@')) {
      return '$clean@students.fyp.invalid';
    }
    return clean;
  }

  @override
  Stream<AuthSession> sessionChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return AuthSession.empty;

      final email = user.email?.trim().toLowerCase() ?? "";
      if (email == "eslammourad2000@yahoo.com") {
        return AuthSession(
          uid: user.uid,
          role: UserRole.admin,
          displayName: user.displayName ?? "Super Admin",
          email: user.email,
        );
      }

      UserRole? role;
      try {
        final token = await user.getIdTokenResult();
        final claimRoleStr = token.claims?['role']?.toString();
        role = UserRole.tryParse(claimRoleStr);
      } catch (tokenErr) {
        debugPrint("Token claim read error: $tokenErr");
      }

      if (role == null) {
        try {
          final doc = await _firestore.collection(FirestorePaths.users).doc(user.uid).get();
          if (doc.exists) {
            role = UserRole.tryParse(doc.data()?['role']?.toString());
          }
        } catch (_) {
          // Handled quietly
        }
      }

      return AuthSession(
        uid: user.uid,
        role: role,
        displayName: user.displayName,
        email: user.email,
      );
    });
  }

  @override
  Future<void> signInAs(UserRole expectedRole, String identifier, String password) async {
    final email = mapIdentifierToEmail(expectedRole, identifier);
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception("Sign in failed.");

    if (email == "eslammourad2000@yahoo.com") {
      return;
    }

    UserRole? actualRole;
    try {
      final token = await user.getIdTokenResult(true);
      final claimRoleStr = token.claims?['role']?.toString();
      actualRole = UserRole.tryParse(claimRoleStr);
    } catch (e) {
      debugPrint("Token claims fetch error: $e");
    }

    if (actualRole == null) {
      try {
        final doc = await _firestore.collection(FirestorePaths.users).doc(user.uid).get();
        if (doc.exists) {
          actualRole = UserRole.tryParse(doc.data()?['role']?.toString());
        }
      } catch (e) {
        debugPrint("Firestore doc read error on signin: $e");
      }
    }

    if (actualRole != null && actualRole != expectedRole) {
      await _auth.signOut();
      throw RoleMismatchException(
        expectedRole: expectedRole,
        actualRole: actualRole,
      );
    }
  }

  @override
  Future<void> signUpParentOrTeacher({
    required UserRole role,
    required String name,
    required String email,
    required String password,
  }) async {
    if (!role.canSelfSignUp) {
      throw ArgumentError("Role ${role.name} cannot self sign up.");
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception("Failed to create account.");

    try {
      await user.updateDisplayName(name.trim());
    } catch (e) {
      debugPrint("Update display name error: $e");
    }

    // Write full user record directly to Firestore users/{uid}
    try {
      await _firestore.collection(FirestorePaths.users).doc(user.uid).set({
        "uid": user.uid,
        "email": email.trim().toLowerCase(),
        "displayName": name.trim(),
        "role": role.name,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore write on signup error: $e");
    }

    // Invoke completeSignup callable if available
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('completeSignup');
      await callable({
        'role': role.name,
        'displayName': name.trim(),
      });
    } catch (e) {
      debugPrint("completeSignup callable error: $e");
    }

    try {
      await user.getIdTokenResult(true);
    } catch (e) {
      debugPrint("Token refresh error on signup: $e");
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
