import test from "node:test";
import assert from "node:assert/strict";
import { HttpsError } from "firebase-functions/v2/https";
import { requireRole, validateSignupRole } from "../src/guards.js";
import { ROLES } from "../src/config.js";
import { hasActiveCourseSubscription } from "../src/entitlements.js";

function expectHttpsError(fn, code) {
  assert.throws(fn, (error) => error instanceof HttpsError && error.code === code);
}

test("requireRole rejects unauthenticated callers", () => {
  expectHttpsError(() => requireRole({}, [ROLES.ADMIN]), "unauthenticated");
});

test("requireRole rejects a caller without an allowed role claim", () => {
  expectHttpsError(
    () => requireRole({ auth: { uid: "u1", token: { email: "eslammourad2000@yahoo.com" } } }, [ROLES.ADMIN]),
    "permission-denied",
  );
});

test("requireRole accepts an allowed role claim", () => {
  assert.equal(
    requireRole({ auth: { uid: "admin-1", token: { role: ROLES.ADMIN } } }, [ROLES.ADMIN]),
    "admin-1",
  );
});

test("signup accepts only a first-time parent or teacher", () => {
  assert.equal(validateSignupRole(ROLES.PARENT, null), ROLES.PARENT);
  assert.equal(validateSignupRole(ROLES.TEACHER, null), ROLES.TEACHER);
});

test("signup rejects student/admin self-signup", () => {
  expectHttpsError(() => validateSignupRole(ROLES.STUDENT, null), "invalid-argument");
  expectHttpsError(() => validateSignupRole(ROLES.ADMIN, null), "invalid-argument");
});

test("signup refuses changing an existing token role", () => {
  expectHttpsError(() => validateSignupRole(ROLES.TEACHER, ROLES.PARENT), "failed-precondition");
});

test("signup refuses changing a role already stored in the user profile", () => {
  expectHttpsError(() => validateSignupRole(ROLES.PARENT, ROLES.TEACHER), "failed-precondition");
});

const now = 1_800_000_000_000;
const subscription = (overrides = {}) => ({
  studentId: "student-1",
  courseId: "course-1",
  status: "active",
  expiresAt: { toMillis: () => now + 60_000 },
  ...overrides,
});

test("paid lesson entitlement accepts only an active, unexpired matching subscription", () => {
  assert.equal(hasActiveCourseSubscription([subscription()], "student-1", "course-1", now), true);
  assert.equal(hasActiveCourseSubscription([subscription({ expiresAt: { toMillis: () => now } })], "student-1", "course-1", now), false);
  assert.equal(hasActiveCourseSubscription([subscription({ status: "pending" })], "student-1", "course-1", now), false);
  assert.equal(hasActiveCourseSubscription([subscription({ studentId: "another-student" })], "student-1", "course-1", now), false);
  assert.equal(hasActiveCourseSubscription([subscription({ courseId: "another-course" })], "student-1", "course-1", now), false);
  assert.equal(hasActiveCourseSubscription([subscription({ expiresAt: null })], "student-1", "course-1", now), false);
});

test("paid lesson entitlement rejects subscriptions without a Firestore-style expiry timestamp", () => {
  assert.equal(
    hasActiveCourseSubscription([{ studentId: "student-1", courseId: "course-1", status: "active", expiresAt: now + 60_000 }], "student-1", "course-1", now),
    false,
  );
});
