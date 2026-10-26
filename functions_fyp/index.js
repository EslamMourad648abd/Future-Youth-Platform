import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

import { REGION, ROLES } from "./src/config.js";
import { requireRole, validateSignupRole } from "./src/guards.js";

if (!getApps().length) {
  initializeApp();
}

const auth = getAuth();
const db = getFirestore();

setGlobalOptions({
  region: REGION,
  timeoutSeconds: 60,
});

export const completeSignup = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const tokenRole = request.auth.token?.role || null;
  const existingUser = await db.collection("users").doc(uid).get();
  const storedRole = existingUser.exists ? existingUser.data()?.role || null : null;
  const role = validateSignupRole(request.data?.role, tokenRole || storedRole);
  const email = (request.auth.token?.email || "").toLowerCase().trim();
  const displayName = String(request.data?.displayName || "").trim();

  // Preserve unrelated custom claims while setting the approved signup role.
  const authUser = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, {
    ...(authUser.customClaims || {}),
    role,
  });

  await db.collection("users").doc(uid).set(
    {
      uid,
      email,
      displayName,
      role,
      ...(role === ROLES.TEACHER ? { approvalStatus: "pending" } : {}),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return {
    ok: true,
    uid,
    role,
    ...(role === ROLES.TEACHER ? { approvalStatus: "pending" } : {}),
  };
});

export const createAdmin = onCall(async (request) => {
  requireRole(request, [ROLES.ADMIN]);

  const email = (request.data?.email || "").toLowerCase().trim();
  const password = request.data?.password || "";
  const displayName = request.data?.displayName || "Admin";

  if (!email || !password || password.length < 6) {
    throw new HttpsError("invalid-argument", "Valid email and password (min 6 chars) required.");
  }

  const userRecord = await auth.createUser({
    email,
    password,
    displayName,
  });

  await auth.setCustomUserClaims(userRecord.uid, { role: ROLES.ADMIN });

  await db.collection("users").doc(userRecord.uid).set({
    uid: userRecord.uid,
    email,
    displayName,
    role: ROLES.ADMIN,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, uid: userRecord.uid };
});

export const createStudent = onCall(async (request) => {
  const parentUid = requireRole(request, [ROLES.PARENT]);

  const rawUsername = (request.data?.username || "").toLowerCase().trim();
  const password = request.data?.password || "";
  const displayName = request.data?.displayName || "Student";

  if (!/^[a-z0-9._]{3,20}$/.test(rawUsername)) {
    throw new HttpsError(
      "invalid-argument",
      "Username must be 3-20 lowercase alphanumeric characters, dots, or underscores."
    );
  }

  const studentEmail = `${rawUsername}@students.fyp.invalid`;

  let userRecord;
  try {
    userRecord = await auth.createUser({
      email: studentEmail,
      password,
      displayName,
    });
  } catch (err) {
    if (err.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Username is already taken.");
    }
    throw new HttpsError("internal", err.message);
  }

  await auth.setCustomUserClaims(userRecord.uid, { role: ROLES.STUDENT });

  await db.collection("users").doc(userRecord.uid).set({
    uid: userRecord.uid,
    username: rawUsername,
    email: studentEmail,
    displayName,
    role: ROLES.STUDENT,
    parentId: parentUid,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, uid: userRecord.uid, username: rawUsername };
});
