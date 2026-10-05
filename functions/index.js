// ------------------------------------------------------
// Firebase Cloud Functions
// Node.js 22 - ESM Safe
// ------------------------------------------------------

import {
  onRequest,
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

import { defineSecret } from "firebase-functions/params";

const zohoCrmApiKey =
  defineSecret("ZOHO_CRM_API_KEY");

const metaGraphApiToken =
  defineSecret("META_GRAPH_API_TOKEN");
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
  ONBOARDING_AGENT: "onboarding_agent",
  SUPPORT_AGENT: "support_agent",
  TRAINEE: "trainee",
  SUPER_ADMIN: "superadmin",

  // Legacy role.
  // Kept temporarily for backward compatibility.
  LEGACY_AGENT: "agent",
});

const allowedRoles = Object.freeze([
  ROLES.ONBOARDING_AGENT,
  ROLES.SUPPORT_AGENT,
  ROLES.TRAINEE,
  ROLES.SUPER_ADMIN,
  ROLES.LEGACY_AGENT,
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
  // Preserve intentional HttpsErrors.
  if (error instanceof HttpsError) {
    return error;
  }

  // Firebase Admin errors.
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

function resolveDisplayName(
  displayName,
  email
) {
  const name =
    typeof displayName === "string"
      ? displayName.trim()
      : "";

  const userEmail =
    typeof email === "string"
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

function requireSuperAdmin(request) {
  if (!request?.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const role =
    request.auth.token?.role;

  if (
    role !== ROLES.SUPER_ADMIN
  ) {
    throw new HttpsError(
      "permission-denied",
      "Super admin only."
    );
  }

  return request.auth.uid;
}


// ======================================================
// Prevent Self-Deletion
// ======================================================

function preventSelfDeletion(
  request,
  targetUid
) {
  if (
    request.auth?.uid === targetUid
  ) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot delete your own account from User Management."
    );
  }
}


// ======================================================
// Prevent Removing Own Super Admin Role
// ======================================================

function preventSelfRoleChange(
  request,
  targetUid,
  newRole
) {
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

// ============================================================
// CRM COMMENT -> ZOHO
// ============================================================

export const updateCrmComment = onCall(
  {
    secrets: [zohoCrmApiKey],
  },
  async (request) => {
  // ----------------------------------------------------------
  // AUTHENTICATION
  // ----------------------------------------------------------

  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to submit a CRM comment."
    );
  }

  // ----------------------------------------------------------
  // INPUT
  // ----------------------------------------------------------

  const data = request.data || {};

  const accountNumber =
    data.accountNumber?.toString().trim() || "";

  const comment =
    data.comment?.toString().trim() || "";

  if (!accountNumber) {
    throw new HttpsError(
      "invalid-argument",
      "Account number is required."
    );
  }

  if (!comment) {
    throw new HttpsError(
      "invalid-argument",
      "Comment is required."
    );
  }

  // ----------------------------------------------------------
  // GET LOGGED-IN USER EMAIL
  // ----------------------------------------------------------

  const userEmail =
    request.auth.token.email?.toString().trim() || "";

  if (!userEmail) {
    throw new HttpsError(
      "failed-precondition",
      "The logged-in user does not have an email address."
    );
  }

  // ----------------------------------------------------------
  // ZOHO API
  // ----------------------------------------------------------

  const zohoUrl =
    "https://www.zohoapis.sa/crm/v7/functions/updatecomment/actions/execute";

  /*
   * IMPORTANT:
   *
   * Store the Zoho API key as a Firebase secret.
   *
   * Do NOT put the actual key here.
   */

  const zohoApiKey =
    zohoCrmApiKey.value();

  if (!zohoApiKey) {
    console.error(
      "ZOHO_CRM_API_KEY is not configured."
    );

    throw new HttpsError(
      "failed-precondition",
      "Zoho CRM integration is not configured."
    );
  }

  // ----------------------------------------------------------
  // REQUEST
  // ----------------------------------------------------------
if (!userEmail) {
  throw new HttpsError(
    "unauthenticated",
    "Authenticated user email is required."
  );
}
const response = await fetch(
  `${zohoUrl}?auth_type=apikey&zapikey=${encodeURIComponent(
    zohoApiKey
  )}`,
  {
    method: "POST",

    headers: {
      "Content-Type": "application/json",
    },

    body: JSON.stringify({
      account_numberr: accountNumber,
      agent_email: userEmail,
      Updated_Note: comment,
    }),
  }
);

  // ----------------------------------------------------------
  // RESPONSE
  // ----------------------------------------------------------

  const responseText =
    await response.text();

  let responseData;

  try {
    responseData =
      JSON.parse(responseText);
  } catch {
    responseData =
      responseText;
  }

  console.log(
    "Zoho CRM comment response:",
    response.status,
    responseData
  );

  if (!response.ok) {
    throw new HttpsError(
      "internal",
      `Zoho CRM request failed with status ${response.status}.`
    );
  }

  return {
    success: true,
    accountNumber,
    userEmail,
    zohoResponse: responseData,
  };
});

// ============================================================
// VERIFICATION STATUS -> ZOHO CRM
// ============================================================

export const updateVerificationStatus = onCall(
  {
    secrets: [zohoCrmApiKey],
  },
  async (request) => {
    // ----------------------------------------------------------
    // AUTHENTICATION
    // ----------------------------------------------------------

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in to update verification status."
      );
    }

    // ----------------------------------------------------------
    // INPUT
    // ----------------------------------------------------------

    const data = request.data || {};

    const accountNumber =
      data.accountNumber?.toString().trim() || "";

    const verificationStatus =
      data.verificationStatus?.toString().trim() || "";

    if (!accountNumber) {
      throw new HttpsError(
        "invalid-argument",
        "Account number is required."
      );
    }

    if (!verificationStatus) {
      throw new HttpsError(
        "invalid-argument",
        "Verification status is required."
      );
    }

    // ----------------------------------------------------------
    // ZOHO API KEY
    // ----------------------------------------------------------

    const zohoUrl =
      "https://www.zohoapis.sa/crm/v7/functions/updatecomment/actions/execute";

    const zohoApiKey =
      zohoCrmApiKey.value();

    if (!zohoApiKey) {
      console.error(
        "ZOHO_CRM_API_KEY is not configured."
      );

      throw new HttpsError(
        "failed-precondition",
        "Zoho CRM integration is not configured."
      );
    }

    // ----------------------------------------------------------
    // REQUEST TO ZOHO
    // ----------------------------------------------------------

    const response = await fetch(
      `${zohoUrl}?auth_type=apikey&zapikey=${encodeURIComponent(
        zohoApiKey
      )}`,
      {
        method: "POST",

        headers: {
          "Content-Type": "application/json",
        },

        body: JSON.stringify({
          account_numberr: accountNumber,
          Meta_Verification: verificationStatus,
        }),
      }
    );

    // ----------------------------------------------------------
    // RESPONSE
    // ----------------------------------------------------------

    const responseText =
      await response.text();

    let responseData;

    try {
      responseData =
        JSON.parse(responseText);
    } catch {
      responseData =
        responseText;
    }

    console.log(
      "Zoho CRM verification response:",
      response.status,
      responseData
    );

    if (!response.ok) {
      throw new HttpsError(
        "internal",
        `Zoho CRM verification request failed with status ${response.status}.`
      );
    }

    return {
      success: true,
      accountNumber,
      verificationStatus,
      zohoResponse: responseData,
    };
  }
);

// ======================================================
// Bevatel Proxy
// ======================================================

export const bevatelProxy = onRequest(
  async (req, res) => {
    res.set(
      "Access-Control-Allow-Origin",
      "*"
    );

    res.set(
      "Access-Control-Allow-Methods",
      "GET, POST, PUT, DELETE, OPTIONS"
    );

    res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization"
    );

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    try {
      const {
        url,
        method,
        headers,
        body,
      } = req.body || {};

      if (
        typeof url !== "string" ||
        !url.trim()
      ) {
        return res.status(400).json({
          error: "Missing URL.",
        });
      }

      if (
        typeof method !== "string" ||
        !method.trim()
      ) {
        return res.status(400).json({
          error: "Missing HTTP method.",
        });
      }

      const normalizedMethod =
        method.toUpperCase();

      console.log(
        "➡️ Forwarding request to:",
        url
      );

      const response =
        await fetch(
          url,
          {
            method:
              normalizedMethod,

            headers:
              headers || {},

            body:
              normalizedMethod !== "GET" &&
              normalizedMethod !== "HEAD" &&
              body !== undefined &&
              body !== null
                ? JSON.stringify(body)
                : undefined,
          }
        );

      const text =
        await response.text();

      let data;

      try {
        data = JSON.parse(text);
      } catch {
        data = text;
      }

      return res
        .status(response.status)
        .json(data);

    } catch (error) {
      console.error(
        "PROXY ERROR:",
        error
      );

      return res.status(500).json({
        error:
          error?.message ||
          "Proxy request failed.",
      });
    }
  }
);


// ======================================================
// List Users
// ======================================================

export const listUsers =
  onCall(async (request) => {
    try {
      requireSuperAdmin(request);

      const snapshot =
        await db
          .collection("users")
          .get();

      const firestoreUsers =
        new Map();

      snapshot.docs.forEach((doc) => {
        const data =
          doc.data() || {};

        firestoreUsers.set(
          doc.id,
          data
        );
      });


      // --------------------------------------------------
      // Read Firebase Auth users as the source of truth
      // for account existence.
      //
      // This also ensures users created in Auth but not
      // yet synchronized into Firestore still appear.
      // --------------------------------------------------

      const users = [];

      let nextPageToken;

      do {
        const result =
          await auth.listUsers(
            1000,
            nextPageToken
          );

        for (
          const authUser
          of result.users
        ) {
          const firestoreData =
            firestoreUsers.get(
              authUser.uid
            ) || {};

          const email =
            authUser.email ||
            firestoreData.email ||
            "";

          const displayName =
            resolveDisplayName(
              authUser.displayName ||
              firestoreData.displayName,
              email
            );

          const role =
            authUser.customClaims?.role ||
            firestoreData.role ||
            ROLES.TRAINEE;

          users.push({
            uid:
              authUser.uid,

            email,

            displayName,

            role,

            disabled:
              authUser.disabled === true,

            createdAt:
              authUser.metadata?.creationTime ||
              null,

            lastSignInTime:
              authUser.metadata?.lastSignInTime ||
              null,
          });
        }

        nextPageToken =
          result.pageToken;

      } while (nextPageToken);


      return {
        users,
      };

    } catch (error) {
      console.error(
        "LIST USERS ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Failed to list users."
      );
    }
  });


// ======================================================
// Create User
// ======================================================

export const createUser =
  onCall(async (request) => {
    try {
      requireSuperAdmin(request);

      const data =
        request.data || {};

      const email =
        normalizeEmail(
          data.email
        );

      const password =
        validatePassword(
          data.password
        );

      const displayName =
        resolveDisplayName(
          data.displayName,
          email
        );

      const role =
        data.role ||
        ROLES.TRAINEE;

      validateRole(role);


      // --------------------------------------------------
      // Create Auth user
      // --------------------------------------------------

      const user =
        await auth.createUser({
          email,

          password,

          displayName,
        });


      try {
        // ----------------------------------------------
        // Set custom claim
        // ----------------------------------------------

        await auth.setCustomUserClaims(
          user.uid,
          {
            role,
          }
        );


        // ----------------------------------------------
        // Create Firestore user
        // ----------------------------------------------

        await db
          .collection("users")
          .doc(user.uid)
          .set({
            uid:
              user.uid,

            displayName,

            email,

            role,

            disabled:
              false,

            createdAt:
              FieldValue.serverTimestamp(),

            updatedAt:
              FieldValue.serverTimestamp(),
          });

      } catch (syncError) {
        // ----------------------------------------------
        // Roll back Auth user if Firestore/claim setup
        // fails.
        // ----------------------------------------------

        console.error(
          "CREATE USER SYNC ERROR:",
          syncError
        );

        try {
          await auth.deleteUser(
            user.uid
          );
        } catch (rollbackError) {
          console.error(
            "CREATE USER ROLLBACK ERROR:",
            rollbackError
          );
        }

        throw syncError;
      }


      return {
        success: true,

        uid:
          user.uid,

        email,

        displayName,

        role,
      };

    } catch (error) {
      console.error(
        "CREATE USER ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Failed creating user."
      );
    }
  });


// ======================================================
// Update User
// ======================================================

export const updateUser =
  onCall(async (request) => {
    try {
      const currentAdminUid =
        requireSuperAdmin(
          request
        );

      const data =
        request.data || {};

      const uid =
        validateUid(
          data.uid
        );


      // --------------------------------------------------
      // Protect current Super Admin
      // --------------------------------------------------

      if (
        uid === currentAdminUid &&
        data.role &&
        data.role !==
          ROLES.SUPER_ADMIN
      ) {
        throw new HttpsError(
          "failed-precondition",
          "You cannot remove your own Super Admin role."
        );
      }


      // --------------------------------------------------
      // Get current Auth user
      // --------------------------------------------------

      const currentUser =
        await auth.getUser(uid);


      // --------------------------------------------------
      // Final email
      // --------------------------------------------------

      let finalEmail =
        currentUser.email || "";

      if (
        data.email !== undefined &&
        data.email !== null &&
        data.email
          .toString()
          .trim()
      ) {
        finalEmail =
          normalizeEmail(
            data.email
          );
      }


      // --------------------------------------------------
      // Final display name
      // --------------------------------------------------

      const finalDisplayName =
        resolveDisplayName(
          data.displayName,
          finalEmail
        );


      // --------------------------------------------------
      // Final role
      // --------------------------------------------------

      let finalRole =
        currentUser.customClaims?.role;

      if (!finalRole) {
        const firestoreUser =
          await db
            .collection("users")
            .doc(uid)
            .get();

        finalRole =
          firestoreUser.exists
            ? firestoreUser.data()?.role
            : null;
      }

      finalRole =
        finalRole ||
        ROLES.TRAINEE;


      if (
        data.role !== undefined &&
        data.role !== null
      ) {
        finalRole =
          validateRole(
            data.role
          );
      }


      // --------------------------------------------------
      // Build Auth update
      // --------------------------------------------------

      const updateData = {};


      if (
        data.email !== undefined &&
        data.email !== null &&
        data.email
          .toString()
          .trim()
      ) {
        updateData.email =
          finalEmail;
      }


      if (
        data.password !== undefined &&
        data.password !== null &&
        data.password
          .toString()
          .trim()
      ) {
        updateData.password =
          validatePassword(
            data.password
          );
      }


      updateData.displayName =
        finalDisplayName;


      if (
        typeof data.disabled ===
        "boolean"
      ) {
        updateData.disabled =
          data.disabled;
      }


      // --------------------------------------------------
      // Update Firebase Auth
      // --------------------------------------------------

      const updatedUser =
        await auth.updateUser(
          uid,
          updateData
        );


      // --------------------------------------------------
      // Update role claim
      // --------------------------------------------------

      await auth.setCustomUserClaims(
        uid,
        {
          role:
            finalRole,
        }
      );


      // --------------------------------------------------
      // Update Firestore
      // --------------------------------------------------

      await db
        .collection("users")
        .doc(uid)
        .set(
          {
            uid,

            displayName:
              finalDisplayName,

            email:
              finalEmail,

            role:
              finalRole,

            disabled:
              updatedUser.disabled === true,

            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );


      return {
        success: true,

        uid:
          updatedUser.uid,

        email:
          finalEmail,

        displayName:
          finalDisplayName,

        role:
          finalRole,

        disabled:
          updatedUser.disabled === true,
      };

    } catch (error) {
      console.error(
        "UPDATE USER ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Failed updating user."
      );
    }
  });


// ======================================================
// Delete User
// ======================================================

export const deleteUser =
  onCall(async (request) => {
    try {
      requireSuperAdmin(request);

      const data =
        request.data || {};

      const uid =
        validateUid(
          data.uid
        );


      // --------------------------------------------------
      // Never allow a Super Admin to delete themselves.
      // --------------------------------------------------

      preventSelfDeletion(
        request,
        uid
      );


      // --------------------------------------------------
      // Make sure user exists before deleting.
      // --------------------------------------------------

      try {
        await auth.getUser(
          uid
        );
      } catch (error) {
        if (
          error?.code ===
          "auth/user-not-found"
        ) {
          throw new HttpsError(
            "not-found",
            "User not found."
          );
        }

        throw error;
      }


      // --------------------------------------------------
      // Delete Auth account
      // --------------------------------------------------

      await auth.deleteUser(
        uid
      );


      // --------------------------------------------------
      // Delete Firestore user
      // --------------------------------------------------

      await db
        .collection("users")
        .doc(uid)
        .delete();


      return {
        success: true,
        uid,
      };

    } catch (error) {
      console.error(
        "DELETE USER ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Failed deleting user."
      );
    }
  });


// ======================================================
// Set User Role
// ======================================================

export const setUserRole =
  onCall(async (request) => {
    try {
      requireSuperAdmin(request);

      const data =
        request.data || {};

      const uid =
        validateUid(
          data.uid
        );

      const role =
        validateRole(
          data.role
        );


      // --------------------------------------------------
      // Prevent removing own Super Admin access.
      // --------------------------------------------------

      preventSelfRoleChange(
        request,
        uid,
        role
      );


      // --------------------------------------------------
      // Verify target user exists.
      // --------------------------------------------------

      await auth.getUser(
        uid
      );


      // --------------------------------------------------
      // Update Firebase Auth claim.
      // --------------------------------------------------

      await auth.setCustomUserClaims(
        uid,
        {
          role,
        }
      );


      // --------------------------------------------------
      // Update Firestore.
      // --------------------------------------------------

      await db
        .collection("users")
        .doc(uid)
        .set(
          {
            uid,

            role,

            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );


      return {
        success: true,

        uid,

        role,
      };

    } catch (error) {
      console.error(
        "SET ROLE ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Failed updating user role."
      );
    }
  });


// ======================================================
// Sync Google Drive Lessons
// ======================================================

export const syncCourseLessons =
  onCall(async (request) => {
    try {
      requireSuperAdmin(
        request
      );

      const data =
        request.data || {};

      const courseId =
        typeof data.courseId ===
        "string"
          ? data.courseId.trim()
          : "";

      const folderId =
        typeof data.folderId ===
        "string"
          ? data.folderId.trim()
          : "";

      if (!courseId || !folderId) {
        throw new HttpsError(
          "invalid-argument",
          "courseId and folderId are required."
        );
      }


      console.log(
        "SYNC COURSE LESSONS START"
      );

      console.log(
        "Course:",
        courseId
      );

      console.log(
        "Drive folder:",
        folderId
      );


      // --------------------------------------------------
      // Verify course exists.
      // --------------------------------------------------

      const courseRef =
        db
          .collection(
            "training_courses"
          )
          .doc(courseId);

      const courseSnapshot =
        await courseRef.get();

      if (!courseSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Training course not found."
        );
      }


      // --------------------------------------------------
      // Read Drive videos.
      // --------------------------------------------------

      const response =
        await drive.files.list({
          q:
            `'${folderId}' in parents and mimeType contains 'video/' and trashed = false`,

          fields:
            "files(id,name,webViewLink,webContentLink)",
        });


      const files =
        response.data.files ||
        [];


      console.log(
        "Videos found:",
        files.length
      );


      // --------------------------------------------------
      // Lessons collection.
      // --------------------------------------------------

      const lessonsRef =
        courseRef.collection(
          "lessons"
        );


      let created = 0;


      // --------------------------------------------------
      // Firestore batches are limited to 500 writes.
      // --------------------------------------------------

      let batch =
        db.batch();

      let batchWrites = 0;


      for (
        const file of files
      ) {
        if (!file.id) {
          continue;
        }


        const existing =
          await lessonsRef
            .where(
              "videoId",
              "==",
              file.id
            )
            .limit(1)
            .get();


        if (!existing.empty) {
          continue;
        }


        const lessonRef =
          lessonsRef.doc();


        batch.set(
          lessonRef,
          {
            title:
              file.name ||
              "Untitled Lesson",

            videoUrl:
              file.webViewLink ||
              file.webContentLink ||
              "",

            videoId:
              file.id,

            createdAt:
              FieldValue.serverTimestamp(),

            updatedAt:
              FieldValue.serverTimestamp(),
          }
        );


        created++;
        batchWrites++;


        if (
          batchWrites >= 450
        ) {
          await batch.commit();

          batch =
            db.batch();

          batchWrites = 0;
        }
      }


      if (
        batchWrites > 0
      ) {
        await batch.commit();
      }


      // --------------------------------------------------
      // Update lesson count.
      // --------------------------------------------------

      const lessonsSnapshot =
        await lessonsRef.get();


      await courseRef.update({
        lessonsCount:
          lessonsSnapshot.size,

        updatedAt:
          FieldValue.serverTimestamp(),
      });


      return {
        success: true,

        courseId,

        lessonsFound:
          files.length,

        lessonsCreated:
          created,

        totalLessons:
          lessonsSnapshot.size,
      };

    } catch (error) {
      console.error(
        "SYNC LESSONS ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Lesson synchronization failed."
      );
    }
  });


// ======================================================
// Migrate User Roles To Firestore
// ======================================================
//
// This function synchronizes Firebase Authentication
// users into Firestore.
//
// It supports more than 1,000 users by using pagination.
//
// It DOES NOT automatically change existing roles.
// It only copies the current Auth role into Firestore.
//
// ======================================================

export const migrateUserRolesToFirestore =
  onCall(async (request) => {
    try {
      requireSuperAdmin(
        request
      );

      let migrated = 0;
      let skipped = 0;

      let nextPageToken;


      do {
        const result =
          await auth.listUsers(
            1000,
            nextPageToken
          );


        for (
          const user
          of result.users
        ) {
          const role =
            user.customClaims?.role;


          // ------------------------------------------------
          // Users without a role are not automatically
          // assigned a role.
          // ------------------------------------------------

          if (!role) {
            skipped++;
            continue;
          }


          // ------------------------------------------------
          // Preserve only supported roles.
          // ------------------------------------------------

          if (
            !allowedRoles.includes(
              role
            )
          ) {
            console.warn(
              `Skipping user ${user.uid}: unsupported role ${role}`
            );

            skipped++;
            continue;
          }


          const email =
            user.email ||
            "";


          const displayName =
            resolveDisplayName(
              user.displayName,
              email
            );


          await db
            .collection("users")
            .doc(user.uid)
            .set(
              {
                uid:
                  user.uid,

                displayName,

                email,

                role,

                disabled:
                  user.disabled === true,

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              }
            );


          migrated++;
        }


        nextPageToken =
          result.pageToken;

      } while (nextPageToken);


      return {
        success: true,

        migrated,

        skipped,
      };

    } catch (error) {
      console.error(
        "MIGRATION ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Role migration failed."
      );
    }
  });


// ======================================================
// Meta Graph API
// ======================================================

const META_GRAPH_API_VERSION = "v23.0";

const META_CLIENT_WABA_ID =
  "228036169000127";

const META_CLIENT_WABA_FIELDS =
  "id,name,whatsapp_business_manager_messaging_limit";

const META_PHONE_NUMBER_FIELDS =
  "id,display_phone_number,quality_rating,status,verified_name";

async function fetchMetaJson(url, token) {
  const controller = new AbortController();
  // 120 second timeout for a SINGLE page fetch
  const timeout = setTimeout(() => controller.abort(), 120000);

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
      signal: controller.signal,
    });

    const text = await response.text();

    let data;

    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }

    if (!response.ok) {
      console.error(
        "META GRAPH API ERROR:",
        response.status,
        data
      );

      const message =
        data?.error?.message ||
        `Meta Graph API request failed with status ${response.status}.`;

      throw new HttpsError(
        "failed-precondition",
        message
      );
    }

    return data;
  } catch (error) {
    if (error?.name === "AbortError") {
      console.error(
        "META GRAPH API REQUEST TIMEOUT:",
        url
      );

      throw new HttpsError(
        "deadline-exceeded",
        "A page request to Meta timed out after 120 seconds. The volume of data (2,000+ accounts) may require multiple attempts or higher server priority."
      );
    }

    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

// ======================================================
// Get ALL Client WhatsApp Business Accounts
// Super Admin Only
// ======================================================

async function fetchAllWabaAccountsFromMeta(token) {
  let nextWabaUrl =
    `https://graph.facebook.com/${META_GRAPH_API_VERSION}/` +
    `${META_CLIENT_WABA_ID}/client_whatsapp_business_accounts` +
    `?limit=100&fields=${encodeURIComponent(META_CLIENT_WABA_FIELDS)}`;

  const allAccounts = [];
  let wabaPage = 0;

  while (nextWabaUrl) {
    wabaPage++;
    console.log(`[META] Fetching WABA Page ${wabaPage} (Total accounts found so far: ${allAccounts.length})...`);

    const page = await fetchMetaJson(nextWabaUrl, token);
    const accounts = Array.isArray(page?.data) ? page.data : [];

    // PARALLEL CHUNKING: Process accounts in parallel batches (50 at a time)
    // This reduces sync time from ~35 mins to ~1-2 mins for 2,000+ accounts.
    const CHUNK_SIZE = 50;
    for (let i = 0; i < accounts.length; i += CHUNK_SIZE) {
      const chunk = accounts.slice(i, i + CHUNK_SIZE);
      console.log(`[META] Processing Parallel Batch: ${i + 1} to ${Math.min(i + CHUNK_SIZE, accounts.length)}...`);

      const chunkResults = await Promise.all(
        chunk.map(async (account) => {
          if (!account.id) return null;

          const phoneNumbers = [];
          let nextPhoneUrl =
            `https://graph.facebook.com/${META_GRAPH_API_VERSION}/${account.id}/phone_numbers` +
            `?limit=100&fields=${encodeURIComponent(META_PHONE_NUMBER_FIELDS)}`;

          let phonePage = 0;
          while (nextPhoneUrl) {
            phonePage++;
            try {
              const phoneResponse = await fetchMetaJson(nextPhoneUrl, token);
              const phones = Array.isArray(phoneResponse?.data) ? phoneResponse.data : [];
              phoneNumbers.push(...phones);
              nextPhoneUrl = phoneResponse?.paging?.next || null;
            } catch (e) {
              console.error(`[META] Phone fetch failed for account ${account.id}:`, e.message);
              break;
            }
            if (phonePage > 10) break;
          }

          return {
            id: account.id,
            name: account?.name ?? "Unnamed Account",
            whatsapp_business_manager_messaging_limit:
              account?.whatsapp_business_manager_messaging_limit ?? "N/A",
            phone_numbers: phoneNumbers,
          };
        })
      );

      // Filter out nulls and add to global list
      allAccounts.push(...chunkResults.filter(a => a !== null));
    }

    nextWabaUrl = page?.paging?.next || null;
    if (wabaPage > 200) break;
  }

  const totalPhoneNumbers = allAccounts.reduce(
    (total, account) => total + account.phone_numbers.length,
    0
  );

  return {
    accounts: allAccounts,
    totalAccounts: allAccounts.length,
    totalPhoneNumbers,
  };
}

export const syncClientWhatsAppBusinessAccounts = onCall(
  {
    secrets: [metaGraphApiToken],
    timeoutSeconds: 900,
    memory: "1GiB",
  },
  async (request) => {
    try {
      console.log(
        "🚀 META WABA SYNC STARTED:",
        new Date().toISOString()
      );
      requireSuperAdmin(request);
      const token = metaGraphApiToken.value();
      if (!token) {
        throw new HttpsError("failed-precondition", "Meta Graph API token is not configured.");
      }

     console.log("🌐 STARTING META FETCH...");

     const metaStart = Date.now();

     const metaData = await fetchAllWabaAccountsFromMeta(token);

     console.log(
       `✅ META FETCH COMPLETED IN ${Date.now() - metaStart}ms`
     );

     console.log(
       `📊 META RESULT: ${metaData.totalAccounts} accounts, ` +
       `${metaData.totalPhoneNumbers} phone numbers`
     );
      const updatedAt = new Date().toISOString();

      // Store accounts in Firestore
      const accountsCollection = db.collection("meta_whatsapp_business_accounts");

      // Delete old accounts first.
      const oldDocs = await accountsCollection.get();

      // Firestore batches are limited to 500 writes.
      // Keep each batch below the limit.
      const writes = [];

      oldDocs.forEach(doc => {
        writes.push({
          type: "delete",
          ref: doc.ref,
        });
      });

      // Add new accounts.
      metaData.accounts.forEach(account => {
        const docRef = accountsCollection.doc(account.id);
        writes.push({
          type: "set",
          ref: docRef,
          data: {
            ...account,
            updatedAt,
          },
        });
      });

      // Update summary.
      const summaryRef = db.collection("meta_whatsapp_business").doc("summary");
      writes.push({
        type: "set",
        ref: summaryRef,
        data: {
          totalAccounts: metaData.totalAccounts,
          totalPhoneNumbers: metaData.totalPhoneNumbers,
          updatedAt,
        },
      });

      console.log(
        `🔥 STARTING FIRESTORE COMMIT: ${writes.length} writes`
      );

      for (let i = 0; i < writes.length; i += 450) {
        const batch = db.batch();
        const chunk = writes.slice(i, i + 450);

        for (const write of chunk) {
          if (write.type === "delete") {
            batch.delete(write.ref);
          } else {
            batch.set(write.ref, write.data);
          }
        }

        await batch.commit();

        console.log(
          `✅ FIRESTORE BATCH COMMITTED: ${Math.min(
            i + chunk.length,
            writes.length
          )}/${writes.length}`
        );
      }

      console.log("🕐 SYNC COMPLETED:", updatedAt);
      console.log("📤 RETURNING SYNC RESPONSE TO CLIENT");
      return {
        ...metaData,
        updatedAt,
        success: true,
      };
    } catch (error) {
      console.error("SYNC CLIENT WHATSAPP BUSINESS ACCOUNTS ERROR:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "Failed to synchronize WhatsApp Business Accounts.");
    }
  }
);
export const getStoredClientWhatsAppBusinessAccounts = onCall(
  async (request) => {
    try {
      requireSuperAdmin(request);

      const summaryDoc = await db.collection("meta_whatsapp_business").doc("summary").get();
      if (!summaryDoc.exists) {
        return {
          accounts: [],
          totalAccounts: 0,
          totalPhoneNumbers: 0,
          updatedAt: null,
          success: true,
        };
      }

      const summary = summaryDoc.data();
      const accountsDocs = await db.collection("meta_whatsapp_business_accounts").get();
      const accounts = accountsDocs.docs.map(doc => doc.data());

      return {
        accounts,
        totalAccounts: summary.totalAccounts,
        totalPhoneNumbers: summary.totalPhoneNumbers,
        updatedAt: summary.updatedAt,
        success: true,
      };
    } catch (error) {
      console.error("GET STORED CLIENT WHATSAPP BUSINESS ACCOUNTS ERROR:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "Failed to retrieve stored WhatsApp Business Accounts.");
    }
  }
);


// ======================================================
// Certificate Configuration
// ======================================================

const PORTAL_HOST_NAME =
  "Eng. Eslam Mourad";


// ======================================================
// Generate / Regenerate Certificate
// ======================================================

export const generateCertificate =
  onCall(async (request) => {
    try {

      // ==================================================
      // AUTHENTICATION
      // ==================================================

      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "Authentication required."
        );
      }


      const userId =
        request.auth.uid;


      const courseId =
        typeof request.data?.courseId ===
        "string"
          ? request.data.courseId.trim()
          : "";


      if (!courseId) {
        throw new HttpsError(
          "invalid-argument",
          "courseId is required."
        );
      }


      console.log(
        "=============================================="
      );

      console.log(
        "GENERATE CERTIFICATE START"
      );

      console.log(
        "User:",
        userId
      );

      console.log(
        "Course:",
        courseId
      );

      console.log(
        "Portal host:",
        PORTAL_HOST_NAME
      );


      // ==================================================
      // GET USER
      // ==================================================

      const userRecord =
        await auth.getUser(
          userId
        );


      const userName =
        resolveDisplayName(
          userRecord.displayName,
          userRecord.email
        );


      // ==================================================
      // GET COURSE
      // ==================================================

      const courseRef =
        db
          .collection(
            "training_courses"
          )
          .doc(courseId);


      const courseSnapshot =
        await courseRef.get();


      if (!courseSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Course not found."
        );
      }


      const courseData =
        courseSnapshot.data() ||
        {};


      const courseTitle =
        courseData.title ||
        courseId;


      // ==================================================
      // GET ACTUAL COURSE LESSONS
      // ==================================================

      const courseLessonsSnapshot =
        await courseRef
          .collection("lessons")
          .get();


      if (
        courseLessonsSnapshot.empty
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Course has no lessons."
        );
      }


      const actualLessonIds =
        new Set(
          courseLessonsSnapshot.docs.map(
            (doc) => doc.id
          )
        );


      const totalLessons =
        courseLessonsSnapshot.size;


      // ==================================================
      // GET USER PROGRESS
      // ==================================================

      const progressSnapshot =
        await db
          .collection("users")
          .doc(userId)
          .collection(
            "training_progress"
          )
          .doc(courseId)
          .collection("lessons")
          .get();


      if (
        progressSnapshot.empty
      ) {
        throw new HttpsError(
          "failed-precondition",
          "No course progress found."
        );
      }


      // ==================================================
      // CALCULATE COMPLETION + QUIZ
      // ==================================================

      let completedLessons = 0;

      let totalQuizScore = 0;

      let submittedQuizCount = 0;

      let latestCompletionDate =
        null;


      for (
        const lessonDoc
        of progressSnapshot.docs
      ) {

        // ------------------------------------------------
        // Ignore orphaned lesson progress.
        // ------------------------------------------------

        if (
          !actualLessonIds.has(
            lessonDoc.id
          )
        ) {
          continue;
        }


        const data =
          lessonDoc.data() ||
          {};


        // ------------------------------------------------
        // Completion.
        // ------------------------------------------------

        if (
          data.completed === true
        ) {
          completedLessons++;


          const completedAt =
            data.completedAt;


          if (
            completedAt &&
            typeof completedAt.toDate ===
              "function"
          ) {
            const completionDate =
              completedAt.toDate();


            if (
              latestCompletionDate === null ||
              completionDate >
                latestCompletionDate
            ) {
              latestCompletionDate =
                completionDate;
            }
          }
        }


        // ------------------------------------------------
        // Quiz.
        // ------------------------------------------------

        if (
          data.quizSubmitted === true
        ) {
          const score =
            Number(
              data.score ?? 0
            );


          if (
            Number.isFinite(score)
          ) {
            totalQuizScore +=
              score;

            submittedQuizCount++;
          }
        }
      }


      // ==================================================
      // VERIFY 100%
      // ==================================================

      if (
        totalLessons === 0 ||
        completedLessons <
          totalLessons
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Course must be 100% completed before generating a certificate."
        );
      }


      // ==================================================
      // QUIZ
      // ==================================================

      const hasQuiz =
        submittedQuizCount > 0;


      const averageQuizScore =
        hasQuiz
          ? totalQuizScore /
            submittedQuizCount
          : null;


      // ==================================================
      // CERTIFICATE ID
      // ==================================================

      const certificateId =
        `${userId}_${courseId}`;


      const certificateRef =
        db
          .collection(
            "certificates"
          )
          .doc(certificateId);


      // ==================================================
      // GET EXISTING CERTIFICATE
      // ==================================================

      const existingCertificate =
        await certificateRef.get();


      const existingData =
        existingCertificate.exists
          ? existingCertificate.data() ||
            {}
          : {};


      // ==================================================
      // RETURN EXISTING CERTIFICATE
      // ==================================================

      if (
        existingCertificate.exists &&
        existingData.certificateUrl &&
        existingData.storagePath
      ) {
        return {
          success: true,

          existing: true,

          regenerated: false,

          certificate: {
            id:
              certificateId,

            userId:
              existingData.userId ||
              userId,

            traineeName:
              existingData.traineeName ||
              userName,

            courseId:
              existingData.courseId ||
              courseId,

            courseTitle:
              existingData.courseTitle ||
              courseTitle,

            certificateNumber:
              existingData.certificateNumber ||
              null,

            certificateUrl:
              existingData.certificateUrl,

            issuedAt:
              existingData.issuedAt ||
              null,

            storagePath:
              existingData.storagePath,

            totalLessons:
              existingData.totalLessons ??
              totalLessons,

            completedLessons:
              existingData.completedLessons ??
              completedLessons,

            hasQuiz:
              existingData.hasQuiz ??
              hasQuiz,

            ...(existingData.hasQuiz
              ? {
                  averageQuizScore:
                    existingData.averageQuizScore ??
                    averageQuizScore,

                  submittedQuizCount:
                    existingData.submittedQuizCount ??
                    submittedQuizCount,

                  totalQuizScore:
                    existingData.totalQuizScore ??
                    totalQuizScore,
                }
              : {}),
          },
        };
      }


      // ==================================================
      // CERTIFICATE NUMBER
      // ==================================================

      const certificateNumber =
        existingData.certificateNumber ||
        `CERT-${new Date().getFullYear()}-${Date.now()}`;


      // ==================================================
      // ISSUED DATE
      // ==================================================

      const issuedAt =
        latestCompletionDate ||
        new Date();


      // ==================================================
      // STORAGE PATH
      // ==================================================

      const storagePath =
        `certificates/${userId}/${courseId}/certificate.pdf`;


      // ==================================================
      // PDF GENERATION
      // ==================================================

      const pdfBuffer =
        await new Promise(
          (resolve, reject) => {

            const document =
              new PDFDocument({
                size: "A4",

                layout: "landscape",

                margin: 0,

                info: {
                  Title:
                    `Certificate of Completion - ${courseTitle}`,

                  Author:
                    "Bevatel",

                  Subject:
                    "Training Certificate",

                  Creator:
                    "Bevatel Training Portal",
                },
              });


            const chunks = [];


            document.on(
              "data",
              (chunk) => {
                chunks.push(chunk);
              }
            );


            document.on(
              "end",
              () => {
                resolve(
                  Buffer.concat(chunks)
                );
              }
            );


            document.on(
              "error",
              reject
            );


            // ==================================================
            // COLORS
            // ==================================================

            const NAVY =
              "#152B5B";

            const DARK_NAVY =
              "#10244D";

            const BLUE =
              "#315F98";

            const LIGHT_BLUE =
              "#76A7D1";

            const PINK =
              "#F5E9EC";

            const DARK_TEXT =
              "#252B35";

            const GREY =
              "#6D7480";

            const WHITE =
              "#FFFFFF";

            const SOFT_GREY =
              "#A7ADB6";


            // ==================================================
            // PAGE SIZE
            // ==================================================

            const pageWidth =
              document.page.width;

            const pageHeight =
              document.page.height;


            // ==================================================
            // BACKGROUND
            // ==================================================

            document
              .rect(
                0,
                0,
                pageWidth,
                pageHeight
              )
              .fill(
                PINK
              );


            // ==================================================
            // RIGHT NAVY PANEL
            // ==================================================

            document
              .save()
              .moveTo(
                pageWidth * 0.57,
                0
              )
              .lineTo(
                pageWidth,
                0
              )
              .lineTo(
                pageWidth,
                pageHeight
              )
              .lineTo(
                pageWidth * 0.44,
                pageHeight
              )
              .bezierCurveTo(
                pageWidth * 0.50,
                pageHeight * 0.77,
                pageWidth * 0.54,
                pageHeight * 0.47,
                pageWidth * 0.57,
                0
              )
              .closePath()
              .fill(
                NAVY
              )
              .restore();


            // ==================================================
            // INNER BLUE CURVE
            // ==================================================

            document
              .save()
              .moveTo(
                pageWidth * 0.54,
                0
              )
              .bezierCurveTo(
                pageWidth * 0.51,
                pageHeight * 0.38,
                pageWidth * 0.47,
                pageHeight * 0.72,
                pageWidth * 0.40,
                pageHeight
              )
              .lineTo(
                pageWidth * 0.44,
                pageHeight
              )
              .bezierCurveTo(
                pageWidth * 0.51,
                pageHeight * 0.69,
                pageWidth * 0.55,
                pageHeight * 0.37,
                pageWidth * 0.58,
                0
              )
              .closePath()
              .fill(
                BLUE
              )
              .restore();


            // ==================================================
            // SECOND BLUE SHADE
            // ==================================================

            document
              .save()
              .moveTo(
                pageWidth * 0.59,
                0
              )
              .bezierCurveTo(
                pageWidth * 0.57,
                pageHeight * 0.35,
                pageWidth * 0.53,
                pageHeight * 0.70,
                pageWidth * 0.47,
                pageHeight
              )
              .lineTo(
                pageWidth * 0.50,
                pageHeight
              )
              .bezierCurveTo(
                pageWidth * 0.56,
                pageHeight * 0.70,
                pageWidth * 0.60,
                pageHeight * 0.32,
                pageWidth * 0.62,
                0
              )
              .closePath()
              .fill(
                DARK_NAVY
              )
              .restore();


            // ==================================================
            // BEVATEL
            // ==================================================

            document
              .fillColor(
                WHITE
              )
              .font(
                "Helvetica-Bold"
              )
              .fontSize(18)
              .text(
                "BEVATEL",
                pageWidth - 160,
                38,
                {
                  width: 115,
                  align: "right",
                }
              );


            document
              .fillColor(
                "#D6DDEA"
              )
              .font(
                "Helvetica"
              )
              .fontSize(6.5)
              .text(
                "BUSINESS CHAT",
                pageWidth - 160,
                61,
                {
                  width: 115,
                  align: "right",
                  characterSpacing: 0.6,
                }
              );


            // ==================================================
            // DECORATIVE BRAND CIRCLE
            // ==================================================

            const brandCircleX =
              pageWidth - 58;

            const brandCircleY =
              92;


            document
              .circle(
                brandCircleX,
                brandCircleY,
                19
              )
              .fill(
                "#D8E3EC"
              );


            document
              .circle(
                brandCircleX - 5,
                brandCircleY - 5,
                13
              )
              .fill(
                BLUE
              );


            document
              .circle(
                brandCircleX + 5,
                brandCircleY + 5,
                9
              )
              .fill(
                "#6D9D80"
              );


            // ==================================================
            // CERTIFICATE TITLE
            // ==================================================

            document
              .fillColor(
                WHITE
              )
              .font(
                "Helvetica-Bold"
              )
              .fontSize(38)
              .text(
                "CERTIFICATE",
                pageWidth * 0.61,
                125,
                {
                  width:
                    pageWidth * 0.34,

                  align: "left",

                  characterSpacing: 0.6,
                }
              );


            document
              .fillColor(
                "#E4D4DA"
              )
              .font(
                "Helvetica"
              )
              .fontSize(17)
              .text(
                "OF COMPLETION",
                pageWidth * 0.615,
                178,
                {
                  width:
                    pageWidth * 0.32,

                  align: "left",

                  characterSpacing: 1.4,
                }
              );


            document
              .moveTo(
                pageWidth * 0.615,
                207
              )
              .lineTo(
                pageWidth * 0.75,
                207
              )
              .lineWidth(1)
              .strokeColor(
                LIGHT_BLUE
              )
              .stroke();


            // ==================================================
            // LEFT CONTENT
            // ==================================================

            const contentWidth =
              pageWidth * 0.43;

            const contentX =
              pageWidth * 0.055;


            document
              .fillColor(
                GREY
              )
              .font(
                "Helvetica"
              )
              .fontSize(11)
              .text(
                "This certificate is proudly presented to",
                contentX,
                125,
                {
                  width:
                    contentWidth,

                  align: "center",
                }
              );


            // ==================================================
            // TRAINEE NAME
            // ==================================================

            let traineeFontSize =
              31;

            const traineeNameWidth =
              contentWidth - 35;


            while (
              traineeFontSize > 18 &&
              document.widthOfString(
                userName,
                {
                  font:
                    "Helvetica-Bold",

                  size:
                    traineeFontSize,
                }
              ) >
                traineeNameWidth
            ) {
              traineeFontSize--;
            }


            document
              .fillColor(
                NAVY
              )
              .font(
                "Helvetica-Bold"
              )
              .fontSize(
                traineeFontSize
              )
              .text(
                userName,
                contentX + 17,
                157,
                {
                  width:
                    traineeNameWidth,

                  align: "center",
                }
              );


            // ==================================================
            // NAME LINE
            // ==================================================

            const nameLineWidth =
              150;

            const nameLineX =
              contentX +
              (
                contentWidth -
                nameLineWidth
              ) /
                2;


            document
              .moveTo(
                nameLineX,
                203
              )
              .lineTo(
                nameLineX +
                  nameLineWidth,
                203
              )
              .lineWidth(1.2)
              .strokeColor(
                BLUE
              )
              .stroke();


            // ==================================================
            // COMPLETION MESSAGE
            // ==================================================

            document
              .fillColor(
                DARK_TEXT
              )
              .font(
                "Helvetica"
              )
              .fontSize(10.5)
              .text(
                "for successfully completing the training course",
                contentX,
                225,
                {
                  width:
                    contentWidth,

                  align: "center",
                }
              );


            // ==================================================
            // COURSE TITLE
            // ==================================================

            let courseFontSize =
              21;

            const courseWidth =
              contentWidth - 35;


            while (
              courseFontSize > 13 &&
              document.widthOfString(
                courseTitle,
                {
                  font:
                    "Helvetica-Bold",

                  size:
                    courseFontSize,
                }
              ) >
                courseWidth
            ) {
              courseFontSize--;
            }


            document
              .fillColor(
                NAVY
              )
              .font(
                "Helvetica-Bold"
              )
              .fontSize(
                courseFontSize
              )
              .text(
                courseTitle,
                contentX + 17,
                255,
                {
                  width:
                    courseWidth,

                  align: "center",

                  lineGap: 3,
                }
              );


            // ==================================================
            // APPRECIATION
            // ==================================================

            const appreciationText =
              "Your commitment, dedication, professionalism, and consistent " +
              "effort have contributed to the successful completion of " +
              "this training journey. We appreciate your continued pursuit " +
              "of learning and professional development.";


            document
              .fillColor(
                DARK_TEXT
              )
              .font(
                "Helvetica"
              )
              .fontSize(8.5)
              .text(
                appreciationText,
                contentX + 20,
                315,
                {
                  width:
                    contentWidth - 40,

                  align: "center",

                  lineGap: 3,
                }
              );


            // ==================================================
            // COMPLETION STATEMENT
            // ==================================================

            let completionStatement =
              `Successfully completed ${completedLessons} of ${totalLessons} lessons`;


            if (
              hasQuiz &&
              averageQuizScore !== null
            ) {
              completionStatement +=
                ` • Average quiz score: ${averageQuizScore.toFixed(1)}%`;
            }


            document
              .fillColor(
                GREY
              )
              .font(
                "Helvetica"
              )
              .fontSize(8)
              .text(
                completionStatement,
                contentX + 15,
                375,
                {
                  width:
                    contentWidth - 30,

                  align: "center",
                }
              );


            // ==================================================
            // PORTAL HOST
            // ==================================================

            const hostLabelY =
              pageHeight - 122;

            const hostValueY =
              pageHeight - 106;


            document
              .fillColor(
                GREY
              )
              .font(
                "Helvetica-Bold"
              )
              .fontSize(6.5)
              .text(
                "TRAINING PORTAL HOST",
                contentX,
                hostLabelY,
                {
                  width:
                    contentWidth,

                  align: "center",

                  characterSpacing: 0.8,
                }
              );


            document
              .fillColor(
                NAVY
              )
              .font(
                "Helvetica-Bold"
              )
              .fontSize(10)
              .text(
                PORTAL_HOST_NAME,
                contentX,
                hostValueY,
                {
                  width:
                    contentWidth,

                  align: "center",
                }
              );


            // ==================================================
            // MANAGEMENT SIGNATURES
            // ==================================================

            const managementSignatureX =
              pageWidth * 0.64;

            const managementSignatureWidth =
              pageWidth * 0.30;

            const managementSignatureStartY =
              pageHeight - 235;

            const managementSignatures = [
              {
                name: "Hassan Ahmed",
                title: "Managing Director",
              },
              {
                name: "Hassan Mohamed",
                title: "Commercial Director",
              },
              {
                name: "Mohamed Esmat",
                title: "Product Operations Manager",
              },
            ];

            managementSignatures.forEach((signature, index) => {
              const y =
                managementSignatureStartY +
                index * 58;

              document
                .moveTo(
                  managementSignatureX,
                  y
                )
                .lineTo(
                  managementSignatureX +
                    managementSignatureWidth,
                  y
                )
                .lineWidth(0.7)
                .strokeColor(
                  "#D6E0EB"
                )
                .stroke();

              document
                .fillColor(WHITE)
                .font(
                  "Helvetica-Bold"
                )
                .fontSize(8.5)
                .text(
                  signature.name,
                  managementSignatureX,
                  y + 7,
                  {
                    width: managementSignatureWidth,
                    align: "center",
                  }
                );

              document
                .fillColor(WHITE)
                .font(
                  "Helvetica-Bold"
                )
                .fontSize(6.5)
                .text(
                  signature.title,
                  managementSignatureX,
                  y + 21,
                  {
                    width: managementSignatureWidth,
                    align: "center",
                  }
                );
            });


            // ==================================================
            // DATE
            // ==================================================

            document
              .fillColor(
                GREY
              )
              .font(
                "Helvetica"
              )
              .fontSize(7)
              .text(
                `Issued: ${formatCertificateDate(issuedAt)}`,
                contentX,
                pageHeight - 25,
                {
                  width:
                    contentWidth,

                  align: "center",
                }
              );


            // ==================================================
            // CERTIFICATE NUMBER
            // ==================================================

            document
              .fillColor(
                "#D5DCE6"
              )
              .font(
                "Helvetica"
              )
              .fontSize(6)
              .text(
                `Certificate No: ${certificateNumber}`,
                pageWidth * 0.63,
                pageHeight - 32,
                {
                  width:
                    pageWidth * 0.30,

                  align: "right",
                }
              );

            // ==================================================
            // RIGHT PANEL TEXT
            // ==================================================

            document
              .fillColor(
                "#D8E1EF"
              )
              .font(
                "Helvetica"
              )
              .fontSize(7)
              .text(
                "TRAINING PORTAL",
                pageWidth * 0.66,
                pageHeight - 65,
                {
                  width:
                    pageWidth * 0.27,

                  align: "right",

                  characterSpacing: 1.2,
                }
              );


            document.end();
          }
        );


      // ==================================================
      // STORAGE
      // ==================================================

      const bucket =
        storage.bucket();

      const file =
        bucket.file(
          storagePath
        );


      // ==================================================
      // Delete Previous PDF
      // ==================================================

      try {
        await file.delete({
          ignoreNotFound: true,
        });
      } catch (deleteError) {
        console.warn(
          "Could not delete old certificate:",
          deleteError?.message
        );
      }


      // ==================================================
      // Upload New PDF
      // ==================================================

      await file.save(
        pdfBuffer,
        {
          resumable: false,

          metadata: {
            contentType:
              "application/pdf",

            cacheControl:
              "no-cache, no-store, must-revalidate",

            metadata: {
              userId,

              courseId,

              certificateNumber,

              hasQuiz:
                String(hasQuiz),

              averageQuizScore:
                hasQuiz &&
                averageQuizScore !== null
                  ? String(
                      averageQuizScore
                    )
                  : "",

              portalHost:
                PORTAL_HOST_NAME,

              generatedAt:
                new Date().toISOString(),
            },
          },
        }
      );


      // ==================================================
      // Signed URL
      // ==================================================

      const [
        certificateUrl,
      ] =
        await file.getSignedUrl({
          action: "read",

          expires:
            "03-09-2491",
        });


      // ==================================================
      // Firestore Certificate Record
      // ==================================================

      const certificateData = {
        userId,

        traineeName:
          userName,

        courseId,

        courseTitle,

        certificateNumber,

        certificateUrl,

        issuedAt,

        storagePath,

        totalLessons,

        completedLessons,

        hasQuiz,

        portalHost:
          PORTAL_HOST_NAME,

        createdAt:
          existingCertificate.exists
            ? (
                existingData.createdAt ||
                FieldValue.serverTimestamp()
              )
            : FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),

        regeneratedAt:
          FieldValue.serverTimestamp(),
      };


      if (
        hasQuiz &&
        averageQuizScore !== null
      ) {
        certificateData.averageQuizScore =
          averageQuizScore;

        certificateData.submittedQuizCount =
          submittedQuizCount;

        certificateData.totalQuizScore =
          totalQuizScore;

      } else {
        certificateData.averageQuizScore =
          FieldValue.delete();

        certificateData.submittedQuizCount =
          FieldValue.delete();

        certificateData.totalQuizScore =
          FieldValue.delete();
      }


      await certificateRef.set(
        certificateData,
        {
          merge: true,
        }
      );


      console.log(
        "GENERATE CERTIFICATE COMPLETE"
      );


      return {
        success: true,

        existing:
          existingCertificate.exists,

        regenerated: true,

        certificate: {
          id:
            certificateId,

          userId,

          traineeName:
            userName,

          courseId,

          courseTitle,

          certificateNumber,

          certificateUrl,

          issuedAt,

          storagePath,

          totalLessons,

          completedLessons,

          hasQuiz,

          portalHost:
            PORTAL_HOST_NAME,

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
      console.error(
        "GENERATE CERTIFICATE ERROR:",
        error
      );

      throw normalizeError(
        error,
        "Failed to generate certificate."
      );
    }
  });


// ======================================================
// Certificate Date Format
// ======================================================

function formatCertificateDate(
  date
) {
  if (!date) {
    return "";
  }

  const actualDate =
    date instanceof Date
      ? date
      : typeof date.toDate ===
          "function"
        ? date.toDate()
        : new Date(date);

  if (
    Number.isNaN(
      actualDate.getTime()
    )
  ) {
    return "";
  }

  return new Intl.DateTimeFormat(
    "en-US",
    {
      month: "short",
      day: "numeric",
      year: "numeric",
    }
  ).format(actualDate);
}
