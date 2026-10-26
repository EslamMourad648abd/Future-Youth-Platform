import { after, before, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { doc, setDoc, getDoc } from "firebase/firestore";
import { ref, uploadString, getBytes } from "firebase/storage";

const here = path.dirname(fileURLToPath(import.meta.url));
const projectId = "demo-future-youth-rules";
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync(path.join(here, "../../firestore.rules"), "utf8") },
    storage: { rules: fs.readFileSync(path.join(here, "../../storage.rules"), "utf8") },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "courses/course-1"), {
      teacherId: "teacher-1",
      status: "draft",
      approvalStatus: "pending",
    });
    await setDoc(doc(db, "courses/course-1/videos/video-1"), {
      teacherId: "teacher-1",
      status: "draft",
      approvalStatus: "pending",
    });
    await setDoc(doc(db, "subscriptions/sub-1"), {
      studentId: "student-1",
      parentId: "parent-1",
      courseId: "course-1",
      status: "active",
    });
  });
});

after(async () => {
  await env?.cleanup();
});

test("private lesson objects cannot be read by students or teachers", async () => {
  const studentStorage = env.authenticatedContext("student-1", { role: "student" }).storage();
  const teacherStorage = env.authenticatedContext("teacher-1", { role: "teacher" }).storage();
  const object = "course-videos/course-1/video-1/lesson.mp4";

  await env.withSecurityRulesDisabled(async (context) => {
    await uploadString(ref(context.storage(), object), "private-video-fixture");
  });

  await assertFails(getBytes(ref(studentStorage, object)));
  await assertFails(getBytes(ref(teacherStorage, object)));
});

test("only the owning teacher can upload a video to their own draft lesson", async () => {
  const owner = env.authenticatedContext("teacher-1", { role: "teacher" }).storage();
  const otherTeacher = env.authenticatedContext("teacher-2", { role: "teacher" }).storage();
  const ownPath = "course-videos/course-1/video-1/lesson.mp4";

  await assertSucceeds(uploadString(ref(owner, ownPath), "video-fixture", {
    contentType: "video/mp4",
  }));
  await assertFails(uploadString(ref(otherTeacher, ownPath), "video-fixture", {
    contentType: "video/mp4",
  }));
  await assertFails(uploadString(ref(owner, "course-videos/course-1/video-1/not-video.txt"), "text", {
    contentType: "text/plain",
  }));
});

test("clients cannot forge subscriptions, paid views, or private video-source metadata", async () => {
  const studentDb = env.authenticatedContext("student-1", { role: "student" }).firestore();

  await assertFails(setDoc(doc(studentDb, "subscriptions/fake-subscription"), {
    studentId: "student-1",
    courseId: "course-1",
    status: "active",
  }));
  await assertFails(setDoc(doc(studentDb, "video_views/fake-view"), {
    studentId: "student-1",
    courseId: "course-1",
    videoId: "video-1",
    viewType: "paid_lesson",
  }));
  await assertFails(setDoc(doc(studentDb, "video_sources/video-1"), {
    courseId: "course-1",
    provider: "firebase_storage",
    storagePath: "course-videos/course-1/video-1/lesson.mp4",
  }));
});

test("students can read their own subscription but not another student's subscription", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "subscriptions/sub-other"), {
      studentId: "student-2",
      parentId: "parent-2",
      courseId: "course-1",
      status: "active",
    });
  });
  const db = env.authenticatedContext("student-1", { role: "student" }).firestore();

  await assertSucceeds(getDoc(doc(db, "subscriptions/sub-1")));
  await assertFails(getDoc(doc(db, "subscriptions/sub-other")));
});
