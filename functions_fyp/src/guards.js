import { HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { ROLES } from "./config.js";

export async function requireRole(request, allowedRoles) {
  if (!request?.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const tokenRole = request.auth.token?.role;
  const isSuperAdminToken = request.auth.token?.superadmin === true || tokenRole === "superadmin";

  const allowed = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

  // 1. Check token claims first
  if (tokenRole && allowed.includes(tokenRole)) {
    return uid;
  }
  if (isSuperAdminToken) {
    return uid;
  }

  // 2. Fallback: Read user document directly from Firestore using Admin SDK
  try {
    const db = getFirestore();
    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      const dbRole = (data?.role || "").toLowerCase().trim();

      if (allowed.includes(dbRole) || dbRole === "admin" || dbRole === "superadmin") {
        return uid;
      }
    }
  } catch (e) {
    console.error("Error reading user role from Firestore:", e);
  }

  throw new HttpsError("permission-denied", "Insufficient permissions.");
}

export function validateSignupRole(role, existingRole = null) {
  if (existingRole) {
    throw new HttpsError(
      "failed-precondition",
      "This account already has a role and cannot change it through sign-up."
    );
  }

  if (role !== ROLES.PARENT && role !== ROLES.TEACHER) {
    throw new HttpsError(
      "invalid-argument",
      "Only parent and teacher roles can self sign up."
    );
  }

  return role;
}
