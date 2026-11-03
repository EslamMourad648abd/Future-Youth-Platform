import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

// One-time bootstrap only. Run from a trusted machine with Application Default
// Credentials for the Future Youth Platform project.
const projectId = "future-youth-platform";
const email = String(process.env.FYP_BOOTSTRAP_ADMIN_EMAIL || "").trim().toLowerCase();

if (!email) {
  throw new Error("Set FYP_BOOTSTRAP_ADMIN_EMAIL to an existing, verified Firebase Auth account.");
}

initializeApp({ credential: applicationDefault(), projectId });
const auth = getAuth();
const db = getFirestore();

const existingAdmins = await db.collection("users").where("role", "==", "admin").limit(1).get();
if (!existingAdmins.empty) {
  throw new Error("An admin profile already exists. Bootstrap is one-time and has been stopped.");
}

const user = await auth.getUserByEmail(email);
if (!user.emailVerified) {
  throw new Error("Verify the Firebase Auth email before bootstrapping the first admin.");
}

const customClaims = { ...(user.customClaims || {}), role: "admin" };
await auth.setCustomUserClaims(user.uid, customClaims);
await db.collection("users").doc(user.uid).set({
  uid: user.uid,
  email: user.email,
  displayName: user.displayName || "Platform Admin",
  role: "admin",
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
  bootstrapCreated: true,
});

console.log(`Bootstrapped the first Future Youth admin for ${email}. Sign out and sign in again to refresh the ID token.`);
