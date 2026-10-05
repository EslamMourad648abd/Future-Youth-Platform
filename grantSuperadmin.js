// grantSuperadmin.js
const admin = require("firebase-admin");
const serviceAccount = require("D:\\bbc_api_tool\\serviceAccountKey.json"); // path to your key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const targetEmail = "eslam.mourad@bevatel.com"; // <-- replace with your own email

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
