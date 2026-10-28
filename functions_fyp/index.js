import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
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
  let courseVideos = null;
  if (decision === "approve" && !videoId) {
    courseVideos = await contentRef.collection("videos").get();
    if (courseVideos.empty) {
      throw new HttpsError("failed-precondition", "Add lessons and upload private videos before approving this course.");
    }
    for (const video of courseVideos.docs) {
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
      const registeredVideoCount = courseVideos.docs.filter((video) => video.data()?.sourceLinked === true).length;
      if (!Number.isInteger(lessonCount) || lessonCount < 1 ||
          courseVideos.docs.length < lessonCount || registeredVideoCount < lessonCount) {
        throw new HttpsError("failed-precondition", "A course needs at least as many registered private lesson videos as its school-book lesson count before approval.");
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

  const sourceRef = db.collection("video_sources").doc(videoId);
  await db.runTransaction(async (tx) => {
    const [currentCourse, currentVideo, currentSource] = await Promise.all([
      tx.get(courseRef),
      tx.get(videoRef),
      tx.get(sourceRef),
    ]);
    if (!currentCourse.exists || currentCourse.data()?.teacherId !== teacherUid ||
        currentCourse.data()?.status !== "draft" ||
        !currentVideo.exists || currentVideo.data()?.teacherId !== teacherUid ||
        currentVideo.data()?.status !== "draft") {
      throw new HttpsError("failed-precondition", "The course and lesson must remain owned drafts during upload registration.");
    }
    tx.set(sourceRef, {
      courseId,
      videoId,
      teacherId: teacherUid,
      provider: "firebase_storage",
      storagePath,
      contentType: metadata.contentType,
      sizeBytes: uploadedSize,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.update(videoRef, { sourceLinked: true, updatedAt: FieldValue.serverTimestamp() });
    if (!currentSource.exists) {
      tx.update(courseRef, {
        videoCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

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
  const existingView = await db.collection("video_views")
    .doc(`${courseId}_${videoId}_${studentId}`).get();
  const eligibleSubscription = subscriptions.docs.find((doc) =>
    hasActiveCourseSubscription([doc], studentId, courseId, now) &&
    (existingView.exists || Number(doc.data()?.pointsRemaining || 0) >= 1)
  );
  if (!eligibleSubscription) {
    throw new HttpsError(
      "permission-denied",
      "An active subscription with a remaining point is required."
    );
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
  const durationSeconds = Math.max(1, Number(videoSnap.data()?.durationSeconds ||
    (Number(videoSnap.data()?.durationMinutes || 1) * 60)));
  const expiresInSeconds = Math.max(900, Math.ceil(durationSeconds + 300));
  const [videoUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + expiresInSeconds * 1000,
  });
  const sessionRef = db.collection("playback_sessions").doc();
  await sessionRef.create({
    sessionId: sessionRef.id,
    studentId,
    courseId,
    videoId,
    teacherId: courseSnap.data()?.teacherId,
    subscriptionId: eligibleSubscription.id,
    viewType: "paid_lesson",
    durationSeconds,
    startedAt: Timestamp.fromMillis(now),
    expiresAt: Timestamp.fromMillis(now + Math.max(30 * 60 * 1000, durationSeconds * 1000 + 10 * 60 * 1000)),
    completed: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, videoUrl, sessionId: sessionRef.id, expiresInSeconds };
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
  const studentId = request.auth.uid;
  const durationSeconds = Math.max(1, Number(videoSnap.data()?.durationSeconds ||
    (Number(videoSnap.data()?.durationMinutes || 1) * 60)));
  const expiresInSeconds = Math.max(900, Math.ceil(durationSeconds + 300));
  const [videoUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + expiresInSeconds * 1000,
  });
  const sessionRef = db.collection("playback_sessions").doc();
  await sessionRef.create({
    sessionId: sessionRef.id,
    studentId,
    courseId,
    videoId,
    teacherId: courseSnap.data()?.teacherId,
    subscriptionId: null,
    viewType: "free_preview",
    durationSeconds,
    startedAt: Timestamp.fromMillis(Date.now()),
    expiresAt: Timestamp.fromMillis(Date.now() + Math.max(30 * 60 * 1000, durationSeconds * 1000 + 10 * 60 * 1000)),
    completed: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, videoUrl, sessionId: sessionRef.id, expiresInSeconds };
});


/**
 * Records server-timestamped playback checkpoints. This raises the cost of
 * bypassing the player: completion requires repeated, time-consistent progress
 * reports, not merely waiting and calling completeVideoView.
 *
 * This is anti-abuse telemetry, not cryptographic proof that a human watched
 * the frames; the client still supplies its playback position.
 */
export const reportVideoPlaybackProgress = onCall(async (request) => {
  const studentId = requireRole(request, [ROLES.STUDENT]);
  const sessionId = String(request.data?.sessionId || "").trim();
  const positionSeconds = Number(request.data?.positionSeconds);
  const isPlaying = request.data?.isPlaying === true;
  if (!sessionId || !Number.isFinite(positionSeconds) || positionSeconds < 0) {
    throw new HttpsError("invalid-argument", "sessionId and a valid playback position are required.");
  }

  const sessionRef = db.collection("playback_sessions").doc(sessionId);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    if (!snap.exists) throw new HttpsError("not-found", "Playback session not found.");
    const session = snap.data();
    const startedAtMs = session.startedAt?.toMillis?.();
    const expiresAtMs = session.expiresAt?.toMillis?.();
    const durationSeconds = Number(session.durationSeconds || 0);
    if (session.studentId !== studentId || !Number.isFinite(startedAtMs) ||
        !Number.isFinite(expiresAtMs) || now > expiresAtMs ||
        !Number.isFinite(durationSeconds) || durationSeconds <= 0 ||
        positionSeconds > durationSeconds + 2) {
      throw new HttpsError("permission-denied", "Playback session is invalid or expired.");
    }
    if (session.completed === true) return;

    const lastAtMs = session.lastProgressAt?.toMillis?.();
    const previousPosition = Number(session.lastPositionSeconds);
    const previousPlaying = session.lastProgressPlaying === true;
    const priorWatchSeconds = Math.max(0, Number(session.verifiedWatchSeconds || 0));
    let addedWatchSeconds = 0;

    if (Number.isFinite(lastAtMs)) {
      const elapsedSeconds = (now - lastAtMs) / 1000;
      if (elapsedSeconds < 4) {
        throw new HttpsError("resource-exhausted", "Playback progress reports are arriving too quickly.");
      }
      // Position may advance no faster than wall time plus a small tolerance.
      const positionDelta = positionSeconds - previousPosition;
      if (positionDelta > elapsedSeconds + 3) {
        throw new HttpsError("failed-precondition", "Playback position advanced too quickly.");
      }
      if (previousPlaying && isPlaying && positionDelta > 0) {
        addedWatchSeconds = Math.min(elapsedSeconds, positionDelta, 15);
      }
    } else if (isPlaying) {
      // The first checkpoint can count only the portion consistent with elapsed
      // time since the server created the playback session.
      addedWatchSeconds = Math.min(positionSeconds, Math.max(0, (now - startedAtMs) / 1000), 15);
    }

    tx.update(sessionRef, {
      lastProgressAt: Timestamp.fromMillis(now),
      lastPositionSeconds: Math.min(durationSeconds, positionSeconds),
      lastProgressPlaying: isPlaying,
      maxReportedPositionSeconds: Math.max(
        Number(session.maxReportedPositionSeconds || 0),
        Math.min(durationSeconds, positionSeconds),
      ),
      verifiedWatchSeconds: Math.min(durationSeconds, priorWatchSeconds + addedWatchSeconds),
      progressEventCount: FieldValue.increment(1),
      lastProgressReceivedAt: FieldValue.serverTimestamp(),
    });
  });

  return { ok: true };
});

export const completeVideoView = onCall(async (request) => {
  const studentId = requireRole(request, [ROLES.STUDENT]);
  const sessionId = String(request.data?.sessionId || "").trim();
  if (!sessionId) throw new HttpsError("invalid-argument", "sessionId is required.");

  const sessionRef = db.collection("playback_sessions").doc(sessionId);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists || sessionSnap.data()?.studentId !== studentId) {
    throw new HttpsError("permission-denied", "Playback session not found for this student.");
  }
  const session = sessionSnap.data();
  const courseId = String(session.courseId || "");
  const videoId = String(session.videoId || "");
  const durationSeconds = Number(session.durationSeconds || 0);
  if (!courseId || !videoId || !Number.isFinite(durationSeconds) || durationSeconds <= 0) {
    throw new HttpsError("failed-precondition", "Playback session metadata is invalid.");
  }

  const courseRef = db.collection("courses").doc(courseId);
  const videoRef = courseRef.collection("videos").doc(videoId);
  const viewRef = db.collection("video_views").doc(`${courseId}_${videoId}_${studentId}`);
  const ledgerRef = db.collection("points_ledger").doc(`view_${courseId}_${videoId}_${studentId}`);
  const now = Date.now();

  const result = await db.runTransaction(async (tx) => {
    const [currentSessionSnap, courseSnap, videoSnap, viewSnap] = await Promise.all([
      tx.get(sessionRef), tx.get(courseRef), tx.get(videoRef), tx.get(viewRef),
    ]);
    if (!currentSessionSnap.exists || !courseSnap.exists || !videoSnap.exists) {
      throw new HttpsError("not-found", "Playback session or lesson no longer exists.");
    }
    const currentSession = currentSessionSnap.data();
    const startedAtMs = currentSession.startedAt?.toMillis?.();
    const expiresAtMs = currentSession.expiresAt?.toMillis?.();
    if (currentSession.studentId !== studentId || currentSession.courseId !== courseId ||
        currentSession.videoId !== videoId || !Number.isFinite(startedAtMs) ||
        !Number.isFinite(expiresAtMs) || now > expiresAtMs) {
      throw new HttpsError("permission-denied", "Playback session is invalid or expired.");
    }
    const verifiedWatchSeconds = Math.max(0, Number(currentSession.verifiedWatchSeconds || 0));
    const maxReportedPositionSeconds = Math.max(0, Number(currentSession.maxReportedPositionSeconds || 0));
    const progressEventCount = Math.max(0, Number(currentSession.progressEventCount || 0));
    if (now < startedAtMs + durationSeconds * 0.9 * 1000) {
      throw new HttpsError("failed-precondition", "At least 90% of the lesson duration must elapse before completion.");
    }
    if (verifiedWatchSeconds < durationSeconds * 0.9 ||
        maxReportedPositionSeconds < durationSeconds * 0.9 ||
        progressEventCount < 2) {
      throw new HttpsError("failed-precondition", "More verified playback progress is required before completion.");
    }
    if (courseSnap.data()?.status !== "published" || courseSnap.data()?.approvalStatus !== "approved" ||
        videoSnap.data()?.status !== "published" || videoSnap.data()?.approvalStatus !== "approved") {
      throw new HttpsError("permission-denied", "Only approved published lessons can be completed.");
    }
    if (viewSnap.exists) {
      tx.update(sessionRef, { completed: true, completedAt: FieldValue.serverTimestamp() });
      return { alreadyCompleted: true, charged: false };
    }

    if (currentSession.viewType === "paid_lesson") {
      const subscriptionId = String(currentSession.subscriptionId || "");
      if (!subscriptionId) throw new HttpsError("failed-precondition", "Subscription is missing from the playback session.");
      const subscriptionRef = db.collection("subscriptions").doc(subscriptionId);
      const subscriptionSnap = await tx.get(subscriptionRef);
      const subscription = subscriptionSnap.data();
      const expiryMs = subscription?.expiresAt?.toMillis?.();
      if (!subscriptionSnap.exists || subscription.studentId !== studentId ||
          subscription.courseId !== courseId || subscription.status !== "active" ||
          !Number.isFinite(expiryMs) || expiryMs <= now ||
          !Number.isInteger(Number(subscription.pointsRemaining)) || Number(subscription.pointsRemaining) < 1) {
        throw new HttpsError("permission-denied", "An active subscription with a remaining point is required.");
      }
      tx.update(subscriptionRef, { pointsRemaining: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp() });
      tx.create(ledgerRef, {
        studentId, courseId, videoId, teacherId: currentSession.teacherId, subscriptionId,
        pointsDelta: -1, entryType: "paid_lesson_completion", createdAt: FieldValue.serverTimestamp(),
      });
    } else if (currentSession.viewType !== "free_preview" || Number(videoSnap.data()?.order || 0) !== 1) {
      throw new HttpsError("permission-denied", "This playback session is not eligible for free preview completion.");
    }

    tx.create(viewRef, {
      studentId, courseId, videoId, teacherId: currentSession.teacherId,
      subscriptionId: currentSession.subscriptionId || null,
      viewType: currentSession.viewType,
      pointsCharged: currentSession.viewType === "paid_lesson",
      viewedAt: FieldValue.serverTimestamp(),
    });
    tx.update(videoRef, { viewCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
    tx.update(sessionRef, { completed: true, completedAt: FieldValue.serverTimestamp() });
    return { alreadyCompleted: false, charged: currentSession.viewType === "paid_lesson" };
  });

  return { ok: true, ...result };
});
