import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

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


/**
 * Admin-only teacher review. Approval state is written by the server, never
 * directly by a client SDK.
 */
export const reviewTeacher = onCall(async (request) => {
  const reviewerUid = requireRole(request, [ROLES.ADMIN]);
  const teacherId = String(request.data?.teacherId || "").trim();
  const decision = request.data?.decision;
  const reason = String(request.data?.reason || "").trim();

  if (!teacherId || !["approve", "reject"].includes(decision)) {
    throw new HttpsError("invalid-argument", "teacherId and approve/reject decision are required.");
  }
  if (decision === "reject" && !reason) {
    throw new HttpsError("invalid-argument", "A rejection reason is required.");
  }

  const teacherRef = db.collection("users").doc(teacherId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(teacherRef);
    if (!snap.exists || snap.data()?.role !== ROLES.TEACHER) {
      throw new HttpsError("not-found", "Teacher profile was not found.");
    }
    tx.update(teacherRef, {
      approvalStatus: decision === "approve" ? "approved" : "rejected",
      reviewedBy: reviewerUid,
      reviewedAt: FieldValue.serverTimestamp(),
      rejectionReason: decision === "reject" ? reason : FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { ok: true, teacherId, approvalStatus: decision === "approve" ? "approved" : "rejected" };
});

/**
 * Admin-only course/video content review.
 * Content documents use courses/{courseId} or courses/{courseId}/videos/{videoId}.
 */
export const reviewCourseContent = onCall(async (request) => {
  const reviewerUid = requireRole(request, [ROLES.ADMIN]);
  const courseId = String(request.data?.courseId || "").trim();
  const videoId = request.data?.videoId == null ? null : String(request.data.videoId).trim();
  const decision = request.data?.decision;
  const reason = String(request.data?.reason || "").trim();

  if (!courseId || (videoId !== null && !videoId) || !["approve", "reject"].includes(decision)) {
    throw new HttpsError("invalid-argument", "courseId, optional videoId, and approve/reject decision are required.");
  }
  if (decision === "reject" && !reason) {
    throw new HttpsError("invalid-argument", "A rejection reason is required.");
  }

  const contentRef = videoId
    ? db.collection("courses").doc(courseId).collection("videos").doc(videoId)
    : db.collection("courses").doc(courseId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(contentRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Submitted content was not found.");
    }
    const data = snap.data();
    if (!data?.teacherId) {
      throw new HttpsError("failed-precondition", "Content must include teacherId before review.");
    }
    if (!videoId && decision === "approve") {
      const lessonCount = Number(data.lessonCount || 0);
      const videoCount = Number(data.videoCount || 0);
      if (!Number.isInteger(lessonCount) || lessonCount < 1 || videoCount < lessonCount) {
        throw new HttpsError("failed-precondition", "A course needs at least as many published videos as its lesson count before approval.");
      }
    }
    const teacherSnap = await tx.get(db.collection("users").doc(data.teacherId));
    if (!teacherSnap.exists || teacherSnap.data()?.role !== ROLES.TEACHER ||
        teacherSnap.data()?.approvalStatus !== "approved") {
      throw new HttpsError("failed-precondition", "The teacher must be approved before content can be approved.");
    }
    tx.update(contentRef, {
      approvalStatus: decision === "approve" ? "approved" : "rejected",
      status: decision === "approve" ? "published" : "rejected",
      reviewedBy: reviewerUid,
      reviewedAt: FieldValue.serverTimestamp(),
      rejectionReason: decision === "reject" ? reason : FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    ok: true,
    courseId,
    ...(videoId ? { videoId } : {}),
    approvalStatus: decision === "approve" ? "approved" : "rejected",
  };
});
