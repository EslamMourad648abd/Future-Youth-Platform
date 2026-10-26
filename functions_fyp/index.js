import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

import { REGION, ROLES } from "./src/config.js";
import { requireRole, validateSignupRole } from "./src/guards.js";
import { hasActiveCourseSubscription } from "./src/entitlements.js";

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

  if (decision === "approve" && videoId) {
    const source = await db.collection("video_sources").doc(videoId).get();
    const sourceData = source.data();
    if (!source.exists || sourceData?.courseId !== courseId ||
        sourceData?.provider !== "firebase_storage" || !sourceData?.storagePath) {
      throw new HttpsError("failed-precondition", "Upload a private video before approving this lesson.");
    }
    const [objectExists] = await getStorage().bucket().file(sourceData.storagePath).exists();
    if (!objectExists) {
      throw new HttpsError("failed-precondition", "The uploaded video is missing from private storage.");
    }
  }
  if (decision === "approve" && !videoId) {
    const videos = await contentRef.collection("videos").get();
    if (videos.empty) {
      throw new HttpsError("failed-precondition", "Add lessons and upload private videos before approving this course.");
    }
    for (const video of videos.docs) {
      const source = await db.collection("video_sources").doc(video.id).get();
      const sourceData = source.data();
      if (!source.exists || sourceData?.courseId !== courseId ||
          sourceData?.provider !== "firebase_storage" || !sourceData?.storagePath) {
        throw new HttpsError("failed-precondition", "Every lesson needs a private uploaded video before the course can be approved.");
      }
      const [objectExists] = await getStorage().bucket().file(sourceData.storagePath).exists();
      if (!objectExists) {
        throw new HttpsError("failed-precondition", "A lesson video is missing from private storage.");
      }
    }
  }

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

/**
 * Registers a teacher-uploaded private Firebase Storage object outside the
 * public course document. Playback is issued only through trusted callables.
 */
export const registerVideoSource = onCall(async (request) => {
  const teacherUid = requireRole(request, [ROLES.TEACHER]);
  const courseId = String(request.data?.courseId || "").trim();
  const videoId = String(request.data?.videoId || "").trim();
  const storagePath = String(request.data?.storagePath || "").trim();
  const expectedPrefix = `course-videos/${courseId}/${videoId}/`;

  if (!courseId || !videoId || !storagePath.startsWith(expectedPrefix) ||
      storagePath.split("/").length !== 4) {
    throw new HttpsError("invalid-argument", "A valid private video upload path is required.");
  }

  const courseRef = db.collection("courses").doc(courseId);
  const videoRef = courseRef.collection("videos").doc(videoId);
  const [courseSnap, videoSnap] = await Promise.all([courseRef.get(), videoRef.get()]);
  if (!courseSnap.exists || courseSnap.data()?.teacherId !== teacherUid ||
      courseSnap.data()?.status !== "draft") {
    throw new HttpsError("permission-denied", "You can only add video sources to your own draft course.");
  }
  if (!videoSnap.exists || videoSnap.data()?.teacherId !== teacherUid ||
      videoSnap.data()?.status !== "draft") {
    throw new HttpsError("permission-denied", "The lesson must be your own draft lesson.");
  }

  const file = getStorage().bucket().file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new HttpsError("failed-precondition", "The uploaded video file could not be found.");
  }
  const [metadata] = await file.getMetadata();
  const uploadedSize = Number(metadata.size || 0);
  if (!String(metadata.contentType || "").startsWith("video/") ||
      !Number.isFinite(uploadedSize) || uploadedSize <= 0 ||
      uploadedSize > 524288000) {
    throw new HttpsError("invalid-argument", "The uploaded file must be a non-empty video no larger than 500 MB.");
  }

  await db.collection("video_sources").doc(videoId).set({
    courseId,
    videoId,
    teacherId: teacherUid,
    provider: "firebase_storage",
    storagePath,
    contentType: metadata.contentType,
    sizeBytes: uploadedSize,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await videoRef.update({ sourceLinked: true, updatedAt: FieldValue.serverTimestamp() });

  return { ok: true, courseId, videoId };
});

/** Paid playback is enabled only when a trusted active subscription exists. */
export const getPaidLessonVideoUrl = onCall(async (request) => {
  requireRole(request, [ROLES.STUDENT]);
  const courseId = String(request.data?.courseId || "").trim();
  const videoId = String(request.data?.videoId || "").trim();
  if (!courseId || !videoId) {
    throw new HttpsError("invalid-argument", "courseId and videoId are required.");
  }

  const courseRef = db.collection("courses").doc(courseId);
  const videoRef = courseRef.collection("videos").doc(videoId);
  const [courseSnap, videoSnap, sourceSnap] = await Promise.all([
    courseRef.get(),
    videoRef.get(),
    db.collection("video_sources").doc(videoId).get(),
  ]);
  if (!courseSnap.exists || !videoSnap.exists ||
      courseSnap.data()?.status !== "published" ||
      courseSnap.data()?.approvalStatus !== "approved" ||
      videoSnap.data()?.status !== "published" ||
      videoSnap.data()?.approvalStatus !== "approved" ||
      videoSnap.data()?.teacherId !== courseSnap.data()?.teacherId ||
      Number(videoSnap.data()?.order || 0) <= 1 ||
      !sourceSnap.exists || sourceSnap.data()?.courseId !== courseId ||
      sourceSnap.data()?.teacherId !== courseSnap.data()?.teacherId ||
      sourceSnap.data()?.provider !== "firebase_storage" ||
      typeof sourceSnap.data()?.storagePath !== "string" ||
      !sourceSnap.data()?.storagePath.startsWith(`course-videos/${courseId}/${videoId}/`)) {
    throw new HttpsError("permission-denied", "This paid lesson is not available for playback.");
  }

  const studentId = request.auth.uid;
  const now = Date.now();
  const subscriptions = await db.collection("subscriptions")
    .where("studentId", "==", studentId)
    .where("courseId", "==", courseId)
    .limit(100)
    .get();
  const entitled = hasActiveCourseSubscription(subscriptions.docs, studentId, courseId, now);
  if (!entitled) {
    throw new HttpsError("permission-denied", "An active, unexpired subscription is required.");
  }

  const teacherSnap = await db.collection("users").doc(courseSnap.data()?.teacherId).get();
  if (!teacherSnap.exists ||
      teacherSnap.data()?.role !== ROLES.TEACHER ||
      teacherSnap.data()?.approvalStatus !== "approved") {
    throw new HttpsError("permission-denied", "The teacher is not currently approved.");
  }

  const file = getStorage().bucket().file(sourceSnap.data().storagePath);
  const [objectExists] = await file.exists();
  if (!objectExists) {
    throw new HttpsError("failed-precondition", "The private lesson video is missing.");
  }
  const [videoUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 5 * 60 * 1000,
  });

  const viewRef = db.collection("video_views").doc(`${courseId}_${videoId}_${studentId}`);
  await db.runTransaction(async (tx) => {
    const [viewSnap, currentVideoSnap] = await Promise.all([tx.get(viewRef), tx.get(videoRef)]);
    if (!currentVideoSnap.exists) throw new HttpsError("not-found", "Lesson not found.");
    if (!viewSnap.exists) {
      tx.create(viewRef, {
        studentId,
        courseId,
        videoId,
        teacherId: courseSnap.data()?.teacherId,
        viewedAt: FieldValue.serverTimestamp(),
        viewType: "paid_lesson",
      });
      tx.update(videoRef, {
        viewCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return { ok: true, videoUrl, expiresInSeconds: 300 };
});

/** Issues a short-lived signed URL only for the approved free first lesson. */
export const getPreviewVideoUrl = onCall(async (request) => {
  requireRole(request, [ROLES.STUDENT]);
  const courseId = String(request.data?.courseId || "").trim();
  const videoId = String(request.data?.videoId || "").trim();
  if (!courseId || !videoId) {
    throw new HttpsError("invalid-argument", "courseId and videoId are required.");
  }
  const courseRef = db.collection("courses").doc(courseId);
  const videoRef = courseRef.collection("videos").doc(videoId);
  const [courseSnap, videoSnap, sourceSnap] = await Promise.all([
    courseRef.get(),
    videoRef.get(),
    db.collection("video_sources").doc(videoId).get(),
  ]);
  if (!courseSnap.exists || !videoSnap.exists ||
      courseSnap.data()?.status !== "published" ||
      courseSnap.data()?.approvalStatus !== "approved" ||
      videoSnap.data()?.status !== "published" ||
      videoSnap.data()?.approvalStatus !== "approved" ||
      Number(videoSnap.data()?.order || 0) !== 1 ||
      !sourceSnap.exists || sourceSnap.data()?.courseId !== courseId) {
    throw new HttpsError("permission-denied", "Only the first approved lesson can be previewed.");
  }
  const teacherSnap = await db.collection("users").doc(courseSnap.data()?.teacherId).get();
  if (!teacherSnap.exists ||
      teacherSnap.data()?.role !== ROLES.TEACHER ||
      teacherSnap.data()?.approvalStatus !== "approved") {
    throw new HttpsError("permission-denied", "The teacher is not currently approved.");
  }

  const storagePath = sourceSnap.data()?.storagePath;
  if (sourceSnap.data()?.provider !== "firebase_storage" ||
      typeof storagePath !== "string" ||
      !storagePath.startsWith(`course-videos/${courseId}/${videoId}/`)) {
    throw new HttpsError("failed-precondition", "Private video storage is not configured for this lesson.");
  }
  const file = getStorage().bucket().file(storagePath);
  const [objectExists] = await file.exists();
  if (!objectExists) {
    throw new HttpsError("failed-precondition", "The private lesson video is missing.");
  }
  const [videoUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 5 * 60 * 1000,
  });

  // Count unique students only after private media is confirmed and a playback
  // URL can be issued. Reopening the same preview does not inflate the count.
  const studentId = request.auth.uid;
  const viewRef = db.collection("video_views").doc(
    `${courseId}_${videoId}_${studentId}`
  );
  await db.runTransaction(async (tx) => {
    const [viewSnap, currentVideoSnap] = await Promise.all([
      tx.get(viewRef),
      tx.get(videoRef),
    ]);
    if (!currentVideoSnap.exists) {
      throw new HttpsError("not-found", "Lesson not found.");
    }
    if (!viewSnap.exists) {
      tx.create(viewRef, {
        studentId,
        courseId,
        videoId,
        teacherId: courseSnap.data()?.teacherId,
        viewedAt: FieldValue.serverTimestamp(),
        viewType: "free_preview",
      });
      tx.update(videoRef, {
        viewCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return { ok: true, videoUrl, expiresInSeconds: 300 };
});
