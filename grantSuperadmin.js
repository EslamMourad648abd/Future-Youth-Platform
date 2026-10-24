// grantSuperadmin.js
const admin = require("firebase-admin");
const serviceAccount = require("D:\\future_youth_platform\\serviceAccountKey.json"); // path to your key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const targetEmail = "eslammourad2000@yahoo.com"; // <-- replace with your own email

async function grantRole() {
  try {
    const user = await admin.auth().getUserByEmail(targetEmail);
    await admin.auth().setCustomUserClaims(user.uid, { superadmin: true });
    console.log(`✅ Superadmin role granted to ${targetEmail}`);
    process.exit(0);
  } catch (err) {
    console.error("❌ Error:", err);
    process.exit(1);
  }
}

grantRole();
