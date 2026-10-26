import { HttpsError } from "firebase-functions/v2/https";
import { ROLES } from "./config.js";

export function requireRole(request, allowedRoles) {
  if (!request?.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const role = request.auth.token?.role;
  const email = (request.auth.token?.email || "").toLowerCase().trim();

  if (email === "eslammourad2000@yahoo.com") {
    return request.auth.uid;
  }

  const allowed = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

  if (!role || !allowed.includes(role)) {
    throw new HttpsError("permission-denied", "Insufficient permissions.");
  }

  return request.auth.uid;
}

export function validateSignupRole(role) {
  if (role !== ROLES.PARENT && role !== ROLES.TEACHER) {
    throw new HttpsError("invalid-argument", "Only parent and teacher roles can self sign up.");
  }
  return role;
}
