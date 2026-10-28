import test from "node:test";
import assert from "node:assert/strict";

import { hasActiveCourseSubscription } from "../src/entitlements.js";

const future = (ms = 60_000) => ({ toMillis: () => 1_000_000 + ms });

test("allows an active, unexpired subscription for the exact student and course", () => {
  assert.equal(hasActiveCourseSubscription([
    { studentId: "student-1", courseId: "course-1", status: "active", expiresAt: future() },
  ], "student-1", "course-1", 1_000_000), true);
});

test("rejects expired, inactive, or mismatched subscriptions", () => {
  const base = { studentId: "student-1", courseId: "course-1", status: "active", expiresAt: future(-1) };
  assert.equal(hasActiveCourseSubscription([base], "student-1", "course-1", 1_000_000), false);
  assert.equal(hasActiveCourseSubscription([{ ...base, status: "pending", expiresAt: future() }], "student-1", "course-1", 1_000_000), false);
  assert.equal(hasActiveCourseSubscription([{ ...base, expiresAt: future() }], "student-2", "course-1", 1_000_000), false);
  assert.equal(hasActiveCourseSubscription([{ ...base, expiresAt: future() }], "student-1", "course-2", 1_000_000), false);
});

test("rejects records without a valid timestamp expiry", () => {
  assert.equal(hasActiveCourseSubscription([
    { studentId: "student-1", courseId: "course-1", status: "active" },
  ], "student-1", "course-1", 1_000_000), false);
});
