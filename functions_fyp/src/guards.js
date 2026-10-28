import { HttpsError } from "firebase-functions/v2/https";
import { ROLES } from "./config.js";

export function requireRole(request, allowedRoles) {
  if (!request?.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const role = request.auth.token?.role;
  const allowed = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

  if (!role || !allowed.includes(role)) {
    throw new HttpsError("permission-denied", "Insufficient permissions.");
  }

  return request.auth.uid;
}

/**
 * Self-signup may only assign a first-time parent/teacher role.
 * A caller who already has any role must use an Admin-managed workflow.
 */
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
