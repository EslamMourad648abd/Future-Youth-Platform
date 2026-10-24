// ------------------------------------------------------
// Firebase Cloud Functions
// Node.js 22 - ESM Safe
// Training Portal & Super Admin Console
// ------------------------------------------------------

import {
  onCall,
  HttpsError,
} from "firebase-functions/v2/https";

import {
  setGlobalOptions,
} from "firebase-functions/v2/options";

import fetch from "node-fetch";

import {
  initializeApp,
  getApps,
} from "firebase-admin/app";

import {
  getAuth,
} from "firebase-admin/auth";

import {
  getFirestore,
  FieldValue,
} from "firebase-admin/firestore";

import {
  getStorage,
} from "firebase-admin/storage";

import PDFDocument from "pdfkit";

import drive from "./google_drive_services.js";

// ======================================================
// Initialize Firebase Admin
// ======================================================

if (!getApps().length) {
  initializeApp();
}

const auth = getAuth();
const db = getFirestore();
const storage = getStorage();

// ======================================================
// Global Settings
// ======================================================

setGlobalOptions({
  region: "us-central1",
  timeoutSeconds: 60,
});

// ======================================================
// Roles Configuration
// ======================================================

const ROLES = Object.freeze({
  ADMIN: "admin",
  TEACHER: "teacher",
  PARENT: "parent",
  STUDENT: "student",
  SUPER_ADMIN: "superadmin",
  TRAINEE: "trainee",
});

const allowedRoles = Object.freeze([
  ROLES.ADMIN,
  ROLES.TEACHER,
  ROLES.PARENT,
  ROLES.STUDENT,
  ROLES.SUPER_ADMIN,
  ROLES.TRAINEE,
]);

// ======================================================
// Role Validation
// ======================================================

function validateRole(role) {
  if (
    typeof role !== "string" ||
    !allowedRoles.includes(role)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid role. Allowed roles: ${allowedRoles.join(", ")}`
    );
  }

  return role;
}

// ======================================================
// Helper: Convert Unknown Error To HttpsError
// ======================================================

function normalizeError(
  error,
  fallbackMessage = "An unexpected error occurred"
) {
  if (error instanceof HttpsError) {
    return error;
  }

  const code =
    typeof error?.code === "string"
      ? error.code
      : "";

  const message =
    error?.message ||
    fallbackMessage;

  switch (code) {
    case "auth/email-already-exists":
      return new HttpsError(
        "already-exists",
        "A user with this email already exists."
      );

    case "auth/invalid-email":
      return new HttpsError(
        "invalid-argument",
        "The email address is invalid."
      );

    case "auth/invalid-password":
    case "auth/password-does-not-meet-requirements":
      return new HttpsError(
        "invalid-argument",
        "The password does not meet the required requirements."
      );

    case "auth/user-not-found":
      return new HttpsError(
        "not-found",
        "User not found."
      );

    case "auth/uid-already-exists":
      return new HttpsError(
        "already-exists",
        "The UID already exists."
      );

    case "auth/too-many-requests":
      return new HttpsError(
        "resource-exhausted",
        "Too many requests. Please try again later."
      );

    case "permission-denied":
      return new HttpsError(
        "permission-denied",
        message
      );

    case "not-found":
      return new HttpsError(
        "not-found",
        message
      );

    default:
      return new HttpsError(
        "internal",
        message
      );
  }
}

// ======================================================
// Helper: Resolve Display Name
// ======================================================

function resolveDisplayName(displayName, email) {
  const name =
    typeof displayName === "string" && displayName.trim()
      ? displayName.trim()
      : "";

  const userEmail =
    typeof email === "string" && email.trim()
      ? email.trim()
      : "";

  return name || userEmail;
}

// ======================================================
// Helper: Normalize Email
// ======================================================

function normalizeEmail(email) {
  if (
    typeof email !== "string" ||
    !email.trim()
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A valid email address is required."
    );
  }

  return email.trim().toLowerCase();
}

// ======================================================
// Helper: Validate UID
// ======================================================

function validateUid(uid) {
  if (
    typeof uid !== "string" ||
    !uid.trim()
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A valid UID is required."
    );
  }

  return uid.trim();
}

// ======================================================
// Helper: Validate Password
// ======================================================

function validatePassword(password) {
  if (
    typeof password !== "string" ||
    !password.trim()
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Password is required."
    );
  }

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must contain at least 6 characters."
    );
  }

  return password;
}

// ======================================================
// Super Admin Permission
// ======================================================

async function requireSuperAdmin(request) {
  if (!request?.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const role = request.auth.token?.role;
  const isSuperAdminClaim = request.auth.token?.superadmin === true;
  const email = (request.auth.token?.email || "").toLowerCase().trim();

  if (
    role === ROLES.ADMIN ||
    role === ROLES.SUPER_ADMIN ||
    isSuperAdminClaim ||
    email === "eslammourad2000@yahoo.com"
  ) {
    return request.auth.uid;
  }

  try {
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data() || {};
      if (userData.role === ROLES.SUPER_ADMIN || userData.role === "superadmin") {
        try {
          await auth.setCustomUserClaims(request.auth.uid, { role: ROLES.SUPER_ADMIN });
        } catch (claimErr) {
          console.warn("Could not set superadmin custom claim:", claimErr);
        }
        return request.auth.uid;
      }
    }
  } catch (dbErr) {
    console.error("Error verifying superadmin in Firestore:", dbErr);
  }

  throw new HttpsError(
    "permission-denied",
    "Super admin only."
  );
}

// ======================================================
// Prevent Self-Deletion
// ======================================================

function preventSelfDeletion(request, targetUid) {
  if (request.auth?.uid === targetUid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot delete your own account from User Management."
    );
  }
}

// ======================================================
// Prevent Removing Own Super Admin Role
// ======================================================

function preventSelfRoleChange(request, targetUid, newRole) {
  if (
    request.auth?.uid === targetUid &&
    newRole !== ROLES.SUPER_ADMIN
  ) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot remove your own Super Admin role."
    );
  }
}

// ======================================================
// List Users
// ======================================================

export const listUsers = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const snapshot = await db.collection("users").get();
    const firestoreUsers = new Map();

    snapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      firestoreUsers.set(doc.id, data);
    });

    const listResult = await auth.listUsers(1000);

    const users = await Promise.all(
      listResult.users.map(async (user) => {
        const firestoreData = firestoreUsers.get(user.uid) || {};
        const customRole = user.customClaims?.role;
        const firestoreRole = firestoreData.role;
        const email = (user.email || "").toLowerCase().trim();

        let role = customRole || firestoreRole;

        if (email === "eslammourad2000@yahoo.com") {
          role = ROLES.SUPER_ADMIN;

          if (customRole !== ROLES.SUPER_ADMIN) {
            try {
              await auth.setCustomUserClaims(user.uid, { role: ROLES.SUPER_ADMIN });
            } catch (claimErr) {
              console.warn("Could not set custom claim for primary admin:", claimErr);
            }
          }

          if (!firestoreData.role || firestoreData.role !== ROLES.SUPER_ADMIN) {
            try {
              await db.collection("users").doc(user.uid).set(
                {
                  uid: user.uid,
                  email: user.email || "eslammourad2000@yahoo.com",
                  displayName: resolveDisplayName(user.displayName, user.email),
                  role: ROLES.SUPER_ADMIN,
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { merge: true }
              );
            } catch (docErr) {
              console.warn("Could not sync firestore doc for primary admin:", docErr);
            }
          }
        } else if (!role) {
          role = ROLES.TRAINEE;
        }

        return {
          uid: user.uid,
          email: user.email || "",
          displayName: resolveDisplayName(user.displayName, user.email),
          role: role,
          createdAt: firestoreData.createdAt || null,
          lastLogin: user.metadata.lastSignInTime || null,
        };
      })
    );

    return { users };
  } catch (error) {
    console.error("LIST USERS ERROR:", error);
    throw normalizeError(error, "Failed to list users.");
  }
});

// ======================================================
// Create User
// ======================================================

export const createUser = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const data = request.data || {};
    const email = normalizeEmail(data.email);
    const password = validatePassword(data.password);
    const role = validateRole(data.role || ROLES.TRAINEE);

    const displayName =
      typeof data.displayName === "string" && data.displayName.trim()
        ? data.displayName.trim()
        : "";

    const userRecord = await auth.createUser({
      email,
      password,
      displayName: displayName || undefined,
    });

    await auth.setCustomUserClaims(userRecord.uid, { role });

    await db.collection("users").doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        email,
        displayName,
        role,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      user: {
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName || "",
        role,
      },
    };
  } catch (error) {
    console.error("CREATE USER ERROR:", error);
    throw normalizeError(error, "Failed to create user.");
  }
});

// ======================================================
// Update User
// ======================================================

export const updateUser = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const data = request.data || {};
    const uid = validateUid(data.uid);

    const updateData = {};
    const firestoreData = {
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (data.email !== undefined) {
      const email = normalizeEmail(data.email);
      updateData.email = email;
      firestoreData.email = email;
    }

    if (data.password !== undefined && String(data.password).trim() !== "") {
      updateData.password = validatePassword(data.password);
    }

    if (data.displayName !== undefined) {
      const displayName = String(data.displayName).trim();
      updateData.displayName = displayName;
      firestoreData.displayName = displayName;
    }

    let roleToSet = null;

    if (data.role !== undefined) {
      const role = validateRole(data.role);
      preventSelfRoleChange(request, uid, role);
      roleToSet = role;
      firestoreData.role = role;
    }

    if (Object.keys(updateData).length > 0) {
      await auth.updateUser(uid, updateData);
    }

    if (roleToSet) {
      await auth.setCustomUserClaims(uid, { role: roleToSet });
    }

    await db.collection("users").doc(uid).set(firestoreData, { merge: true });

    return {
      success: true,
      uid,
    };
  } catch (error) {
    console.error("UPDATE USER ERROR:", error);
    throw normalizeError(error, "Failed to update user.");
  }
});

// ======================================================
// Delete User
// ======================================================

export const deleteUser = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const data = request.data || {};
    const uid = validateUid(data.uid);

    preventSelfDeletion(request, uid);

    await auth.deleteUser(uid);
    await db.collection("users").doc(uid).delete();

    return {
      success: true,
      uid,
    };
  } catch (error) {
    console.error("DELETE USER ERROR:", error);
    throw normalizeError(error, "Failed to delete user.");
  }
});

// ======================================================
// Set User Role
// ======================================================

export const setUserRole = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const data = request.data || {};
    const uid = validateUid(data.uid);
    const role = validateRole(data.role);

    preventSelfRoleChange(request, uid, role);

    await auth.setCustomUserClaims(uid, { role });

    await db.collection("users").doc(uid).set(
      {
        role,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      uid,
      role,
    };
  } catch (error) {
    console.error("SET USER ROLE ERROR:", error);
    throw normalizeError(error, "Failed to set user role.");
  }
});

// ======================================================
// Sync Course Lessons from Google Drive
// ======================================================

export const syncCourseLessons = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const courseId = request.data?.courseId;

    if (!courseId) {
      throw new HttpsError("invalid-argument", "courseId is required");
    }

    const courseDoc = await db.collection("training_courses").doc(courseId).get();

    if (!courseDoc.exists) {
      throw new HttpsError("not-found", "Course not found");
    }

    const courseData = courseDoc.data();
    const driveFolderId = courseData.driveFolderId;

    if (!driveFolderId) {
      throw new HttpsError("failed-precondition", "Drive folder ID missing");
    }

    const files = await drive.files.list({
      q: `'${driveFolderId}' in parents and mimeType contains 'video/' and trashed = false`,
      fields: "files(id, name, webViewLink, webContentLink)",
      orderBy: "name",
    });

    const videos = files.data.files || [];
    const lessonsRef = db.collection("training_courses").doc(courseId).collection("lessons");

    const batch = db.batch();

    videos.forEach((file, index) => {
      const lessonDoc = lessonsRef.doc(file.id);

      batch.set(
        lessonDoc,
        {
          title: file.name,
          videoUrl: file.webViewLink,
          driveFileId: file.id,
          order: index + 1,
          updatedAt: new Date(),
        },
        { merge: true }
      );
    });

    await batch.commit();

    await db.collection("training_courses").doc(courseId).update({
      lessonsCount: videos.length,
      lastSyncedAt: new Date(),
    });

    return {
      success: true,
      lessonsCount: videos.length,
    };
  } catch (error) {
    console.error("SYNC LESSONS ERROR:", error);
    throw normalizeError(error, "Failed to sync lessons");
  }
});

// ======================================================
// Migrate Existing User Roles To Firestore
// ======================================================

export const migrateUserRolesToFirestore = onCall(async (request) => {
  try {
    await requireSuperAdmin(request);

    const listResult = await auth.listUsers(1000);
    const users = listResult.users;

    const batch = db.batch();
    let migratedCount = 0;

    for (const user of users) {
      const customRole = user.customClaims?.role;
      const role = customRole || ROLES.TRAINEE;

      const userDocRef = db.collection("users").doc(user.uid);

      batch.set(
        userDocRef,
        {
          uid: user.uid,
          email: user.email || "",
          displayName: resolveDisplayName(user.displayName, user.email),
          role: role,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      migratedCount++;
    }

    await batch.commit();

    return {
      success: true,
      message: `Migrated ${migratedCount} user roles to Firestore.`,
      migratedCount,
    };
  } catch (error) {
    console.error("MIGRATE USER ROLES ERROR:", error);
    throw normalizeError(error, "Failed to migrate user roles.");
  }
});

// ======================================================
// Certificate Configuration
// ======================================================

const PORTAL_HOST_NAME = "Eng. Eslam Mourad";

// ======================================================
// Generate / Regenerate Certificate
// ======================================================

export const generateCertificate = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const userId = request.auth.uid;
    const courseId =
      typeof request.data?.courseId === "string"
        ? request.data.courseId.trim()
        : "";

    if (!courseId) {
      throw new HttpsError("invalid-argument", "courseId is required.");
    }

    const userRecord = await auth.getUser(userId);
    const userName = resolveDisplayName(userRecord.displayName, userRecord.email);

    const courseRef = db.collection("training_courses").doc(courseId);
    const courseSnapshot = await courseRef.get();

    if (!courseSnapshot.exists) {
      throw new HttpsError("not-found", "Course not found.");
    }

    const courseData = courseSnapshot.data() || {};
    const courseTitle = courseData.title || courseId;

    const courseLessonsSnapshot = await courseRef.collection("lessons").get();

    if (courseLessonsSnapshot.empty) {
      throw new HttpsError("failed-precondition", "Course has no lessons.");
    }

    const actualLessonIds = new Set(courseLessonsSnapshot.docs.map((doc) => doc.id));
    const totalLessons = courseLessonsSnapshot.size;

    const progressSnapshot = await db
      .collection("users")
      .doc(userId)
      .collection("training_progress")
      .doc(courseId)
      .collection("lessons")
      .get();

    if (progressSnapshot.empty) {
      throw new HttpsError("failed-precondition", "No course progress found.");
    }

    let completedLessons = 0;
    let totalQuizScore = 0;
    let submittedQuizCount = 0;
    let latestCompletionDate = null;

    for (const lessonDoc of progressSnapshot.docs) {
      if (!actualLessonIds.has(lessonDoc.id)) {
        continue;
      }

      const data = lessonDoc.data() || {};

      if (data.completed === true) {
        completedLessons++;
        const completedAt = data.completedAt;
        if (completedAt && typeof completedAt.toDate === "function") {
          const completionDate = completedAt.toDate();
          if (latestCompletionDate === null || completionDate > latestCompletionDate) {
            latestCompletionDate = completionDate;
          }
        }
      }

      if (data.quizSubmitted === true) {
        const score = Number(data.score ?? 0);
        if (Number.isFinite(score)) {
          totalQuizScore += score;
          submittedQuizCount++;
        }
      }
    }

    if (totalLessons === 0 || completedLessons < totalLessons) {
      throw new HttpsError(
        "failed-precondition",
        "Course must be 100% completed before generating a certificate."
      );
    }

    const hasQuiz = submittedQuizCount > 0;
    const averageQuizScore = hasQuiz ? totalQuizScore / submittedQuizCount : null;
    const certificateId = `${userId}_${courseId}`;
    const certificateRef = db.collection("certificates").doc(certificateId);

    const existingCertificate = await certificateRef.get();
    const existingData = existingCertificate.exists
      ? existingCertificate.data() || {}
      : {};

    if (existingCertificate.exists && existingData.certificateUrl && existingData.storagePath) {
      return {
        success: true,
        existing: true,
        regenerated: false,
        certificate: {
          id: certificateId,
          userId: existingData.userId || userId,
          traineeName: existingData.traineeName || userName,
          courseId: existingData.courseId || courseId,
          courseTitle: existingData.courseTitle || courseTitle,
          certificateNumber: existingData.certificateNumber || null,
          certificateUrl: existingData.certificateUrl,
          issuedAt: existingData.issuedAt || null,
          storagePath: existingData.storagePath,
          totalLessons: existingData.totalLessons ?? totalLessons,
          completedLessons: existingData.completedLessons ?? completedLessons,
          hasQuiz: existingData.hasQuiz ?? hasQuiz,
          ...(existingData.hasQuiz
            ? {
                averageQuizScore: existingData.averageQuizScore ?? averageQuizScore,
                submittedQuizCount: existingData.submittedQuizCount ?? submittedQuizCount,
                totalQuizScore: existingData.totalQuizScore ?? totalQuizScore,
              }
            : {}),
        },
      };
    }

    const certificateNumber =
      existingData.certificateNumber ||
      `CERT-${new Date().getFullYear()}-${Date.now()}`;

    const issuedAt = latestCompletionDate || new Date();
    const storagePath = `certificates/${userId}/${courseId}/certificate.pdf`;

    const pdfBuffer = await new Promise((resolve, reject) => {
      const document = new PDFDocument({
        size: "A4",
        layout: "landscape",
        margin: 0,
        info: {
          Title: `Certificate of Completion - ${courseTitle}`,
          Author: "Bevatel",
          Subject: "Training Certificate",
          Creator: "Bevatel Training Portal",
        },
      });

      const chunks = [];
      document.on("data", (chunk) => chunks.push(chunk));
      document.on("end", () => resolve(Buffer.concat(chunks)));
      document.on("error", reject);

      const NAVY = "#152B5B";
      const DARK_NAVY = "#10244D";
      const BLUE = "#315F98";
      const LIGHT_BLUE = "#76A7D1";
      const PINK = "#F5E9EC";
      const DARK_TEXT = "#252B35";
      const GREY = "#6D7480";
      const WHITE = "#FFFFFF";

      const pageWidth = document.page.width;
      const pageHeight = document.page.height;

      document.rect(0, 0, pageWidth, pageHeight).fill(PINK);

      document
        .save()
        .moveTo(pageWidth * 0.57, 0)
        .lineTo(pageWidth, 0)
        .lineTo(pageWidth, pageHeight)
        .lineTo(pageWidth * 0.44, pageHeight)
        .bezierCurveTo(
          pageWidth * 0.50,
          pageHeight * 0.77,
          pageWidth * 0.54,
          pageHeight * 0.47,
          pageWidth * 0.57,
          0
        )
        .closePath()
        .fill(NAVY)
        .restore();

      document
        .save()
        .moveTo(pageWidth * 0.54, 0)
        .bezierCurveTo(
          pageWidth * 0.51,
          pageHeight * 0.38,
          pageWidth * 0.47,
          pageHeight * 0.72,
          pageWidth * 0.40,
          pageHeight
        )
        .lineTo(pageWidth * 0.44, pageHeight)
        .bezierCurveTo(
          pageWidth * 0.51,
          pageHeight * 0.69,
          pageWidth * 0.55,
          pageHeight * 0.37,
          pageWidth * 0.58,
          0
        )
        .closePath()
        .fill(BLUE)
        .restore();

      document
        .save()
        .moveTo(pageWidth * 0.59, 0)
        .bezierCurveTo(
          pageWidth * 0.57,
          pageHeight * 0.35,
          pageWidth * 0.53,
          pageHeight * 0.70,
          pageWidth * 0.47,
          pageHeight
        )
        .lineTo(pageWidth * 0.50, pageHeight)
        .bezierCurveTo(
          pageWidth * 0.56,
          pageHeight * 0.70,
          pageWidth * 0.60,
          pageHeight * 0.32,
          pageWidth * 0.62,
          0
        )
        .closePath()
        .fill(DARK_NAVY)
        .restore();

      document
        .fillColor(WHITE)
        .font("Helvetica-Bold")
        .fontSize(18)
        .text("BEVATEL", pageWidth - 160, 38, {
          width: 115,
          align: "right",
        });

      document
        .fillColor("#D6DDEA")
        .font("Helvetica")
        .fontSize(6.5)
        .text("BUSINESS CHAT", pageWidth - 160, 61, {
          width: 115,
          align: "right",
          characterSpacing: 0.6,
        });

      const brandCircleX = pageWidth - 58;
      const brandCircleY = 92;

      document.circle(brandCircleX, brandCircleY, 19).fill("#D8E3EC");
      document.circle(brandCircleX - 5, brandCircleY - 5, 13).fill(BLUE);
      document.circle(brandCircleX + 5, brandCircleY + 5, 9).fill("#6D9D80");

      document
        .fillColor(WHITE)
        .font("Helvetica-Bold")
        .fontSize(38)
        .text("CERTIFICATE", pageWidth * 0.61, 125, {
          width: pageWidth * 0.34,
          align: "left",
          characterSpacing: 0.6,
        });

      document
        .fillColor("#E4D4DA")
        .font("Helvetica")
        .fontSize(17)
        .text("OF COMPLETION", pageWidth * 0.615, 178, {
          width: pageWidth * 0.32,
          align: "left",
          characterSpacing: 1.4,
        });

      document
        .moveTo(pageWidth * 0.615, 207)
        .lineTo(pageWidth * 0.75, 207)
        .lineWidth(1)
        .strokeColor(LIGHT_BLUE)
        .stroke();

      const contentWidth = pageWidth * 0.43;
      const contentX = pageWidth * 0.055;

      document
        .fillColor(GREY)
        .font("Helvetica")
        .fontSize(11)
        .text("This certificate is proudly presented to", contentX, 125, {
          width: contentWidth,
          align: "center",
        });

      let traineeFontSize = 31;
      const traineeNameWidth = contentWidth - 35;

      while (
        traineeFontSize > 18 &&
        document.widthOfString(userName, {
          font: "Helvetica-Bold",
          size: traineeFontSize,
        }) > traineeNameWidth
      ) {
        traineeFontSize--;
      }

      document
        .fillColor(NAVY)
        .font("Helvetica-Bold")
        .fontSize(traineeFontSize)
        .text(userName, contentX + 17, 157, {
          width: traineeNameWidth,
          align: "center",
        });

      const nameLineWidth = 150;
      const nameLineX = contentX + (contentWidth - nameLineWidth) / 2;

      document
        .moveTo(nameLineX, 203)
        .lineTo(nameLineX + nameLineWidth, 203)
        .lineWidth(1.2)
        .strokeColor(BLUE)
        .stroke();

      document
        .fillColor(DARK_TEXT)
        .font("Helvetica")
        .fontSize(10.5)
        .text("for successfully completing the training course", contentX, 225, {
          width: contentWidth,
          align: "center",
        });

      let courseFontSize = 21;
      const courseWidth = contentWidth - 35;

      while (
        courseFontSize > 13 &&
        document.widthOfString(courseTitle, {
          font: "Helvetica-Bold",
          size: courseFontSize,
        }) > courseWidth
      ) {
        courseFontSize--;
      }

      document
        .fillColor(NAVY)
        .font("Helvetica-Bold")
        .fontSize(courseFontSize)
        .text(courseTitle, contentX + 17, 255, {
          width: courseWidth,
          align: "center",
          lineGap: 3,
        });

      const appreciationText =
        "Your commitment, dedication, professionalism, and consistent " +
        "effort have contributed to the successful completion of " +
        "this training journey. We appreciate your continued pursuit " +
        "of learning and professional development.";

      document
        .fillColor(DARK_TEXT)
        .font("Helvetica")
        .fontSize(8.5)
        .text(appreciationText, contentX + 20, 315, {
          width: contentWidth - 40,
          align: "center",
          lineGap: 3,
        });

      let completionStatement = `Successfully completed ${completedLessons} of ${totalLessons} lessons`;
      if (hasQuiz && averageQuizScore !== null) {
        completionStatement += ` • Average quiz score: ${averageQuizScore.toFixed(1)}%`;
      }

      document
        .fillColor(GREY)
        .font("Helvetica")
        .fontSize(8)
        .text(completionStatement, contentX + 15, 375, {
          width: contentWidth - 30,
          align: "center",
        });

      const hostLabelY = pageHeight - 122;
      const hostValueY = pageHeight - 106;

      document
        .fillColor(GREY)
        .font("Helvetica-Bold")
        .fontSize(6.5)
        .text("TRAINING PORTAL HOST", contentX, hostLabelY, {
          width: contentWidth,
          align: "center",
          characterSpacing: 0.8,
        });

      document
        .fillColor(NAVY)
        .font("Helvetica-Bold")
        .fontSize(10)
        .text(PORTAL_HOST_NAME, contentX, hostValueY, {
          width: contentWidth,
          align: "center",
        });

      const managementSignatureX = pageWidth * 0.64;
      const managementSignatureWidth = pageWidth * 0.30;
      const managementSignatureStartY = pageHeight - 235;

      const managementSignatures = [
        { name: "Hassan Ahmed", title: "Managing Director" },
        { name: "Hassan Mohamed", title: "Commercial Director" },
        { name: "Mohamed Esmat", title: "Product Operations Manager" },
      ];

      managementSignatures.forEach((signature, index) => {
        const y = managementSignatureStartY + index * 58;

        document
          .moveTo(managementSignatureX, y)
          .lineTo(managementSignatureX + managementSignatureWidth, y)
          .lineWidth(0.7)
          .strokeColor("#D6E0EB")
          .stroke();

        document
          .fillColor(WHITE)
          .font("Helvetica-Bold")
          .fontSize(8.5)
          .text(signature.name, managementSignatureX, y + 7, {
            width: managementSignatureWidth,
            align: "center",
          });

        document
          .fillColor(WHITE)
          .font("Helvetica-Bold")
          .fontSize(6.5)
          .text(signature.title, managementSignatureX, y + 21, {
            width: managementSignatureWidth,
            align: "center",
          });
      });

      document
        .fillColor(GREY)
        .font("Helvetica")
        .fontSize(7)
        .text(`Issued: ${formatCertificateDate(issuedAt)}`, contentX, pageHeight - 25, {
          width: contentWidth,
          align: "center",
        });

      document
        .fillColor("#D5DCE6")
        .font("Helvetica")
        .fontSize(6)
        .text(`Certificate No: ${certificateNumber}`, pageWidth * 0.63, pageHeight - 32, {
          width: pageWidth * 0.30,
          align: "right",
        });

      document
        .fillColor("#D8E1EF")
        .font("Helvetica")
        .fontSize(7)
        .text("TRAINING PORTAL", pageWidth * 0.66, pageHeight - 65, {
          width: pageWidth * 0.27,
          align: "right",
          characterSpacing: 1.2,
        });

      document.end();
    });

    const bucket = storage.bucket();
    const file = bucket.file(storagePath);

    try {
      await file.delete({ ignoreNotFound: true });
    } catch (deleteError) {
      console.warn("Could not delete old certificate:", deleteError?.message);
    }

    await file.save(pdfBuffer, {
      resumable: false,
      metadata: {
        contentType: "application/pdf",
        cacheControl: "no-cache, no-store, must-revalidate",
        metadata: {
          userId,
          courseId,
          certificateNumber,
          hasQuiz: String(hasQuiz),
          averageQuizScore:
            hasQuiz && averageQuizScore !== null ? String(averageQuizScore) : "",
          portalHost: PORTAL_HOST_NAME,
          generatedAt: new Date().toISOString(),
        },
      },
    });

    const [certificateUrl] = await file.getSignedUrl({
      action: "read",
      expires: "03-09-2491",
    });

    const certificateData = {
      userId,
      traineeName: userName,
      courseId,
      courseTitle,
      certificateNumber,
      certificateUrl,
      issuedAt,
      storagePath,
      totalLessons,
      completedLessons,
      hasQuiz,
      portalHost: PORTAL_HOST_NAME,
      createdAt: existingCertificate.exists
        ? existingData.createdAt || FieldValue.serverTimestamp()
        : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      regeneratedAt: FieldValue.serverTimestamp(),
    };

    if (hasQuiz && averageQuizScore !== null) {
      certificateData.averageQuizScore = averageQuizScore;
      certificateData.submittedQuizCount = submittedQuizCount;
      certificateData.totalQuizScore = totalQuizScore;
    } else {
      certificateData.averageQuizScore = FieldValue.delete();
      certificateData.submittedQuizCount = FieldValue.delete();
      certificateData.totalQuizScore = FieldValue.delete();
    }

    await certificateRef.set(certificateData, { merge: true });

    return {
      success: true,
      existing: existingCertificate.exists,
      regenerated: true,
      certificate: {
        id: certificateId,
        userId,
        traineeName: userName,
        courseId,
        courseTitle,
        certificateNumber,
        certificateUrl,
        issuedAt,
        storagePath,
        totalLessons,
        completedLessons,
        hasQuiz,
        portalHost: PORTAL_HOST_NAME,
        ...(hasQuiz
          ? {
              averageQuizScore,
              submittedQuizCount,
              totalQuizScore,
            }
          : {}),
      },
    };
  } catch (error) {
    console.error("GENERATE CERTIFICATE ERROR:", error);
    throw normalizeError(error, "Failed to generate certificate.");
  }
});

// ======================================================
// Certificate Date Format
// ======================================================

function formatCertificateDate(date) {
  if (!date) return "";

  const actualDate =
    date instanceof Date
      ? date
      : typeof date.toDate === "function"
      ? date.toDate()
      : new Date(date);

  if (Number.isNaN(actualDate.getTime())) return "";

  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(actualDate);
}
