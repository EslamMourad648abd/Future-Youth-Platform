// migrateRoles.js

import { initializeApp, cert, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import serviceAccount from "./bbc-api-tool-firebase-adminsdk-fbsvc-344ab63826.json" with { type: "json" };

if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount),
  });
}

const auth = getAuth();



async function migrateRoles() {

  console.log("🚀 Starting roles migration...");


  const users = await auth.listUsers(1000);


  for (const user of users.users) {

    const oldClaims = user.customClaims || {};


    let newRole;


    // Existing super admins
    if (oldClaims.superadmin === true) {

      newRole = "superadmin";

    }
    else {

      // Existing normal users
      newRole = "agent";

    }


    await auth.setCustomUserClaims(
      user.uid,
      {
        role: newRole
      }
    );


    console.log(
      `✅ ${user.email} -> ${newRole}`
    );

  }


  console.log(
    "🎉 Migration completed successfully"
  );


  process.exit(0);

}



migrateRoles()
.catch((error)=>{

  console.error(
    "❌ Migration failed:",
    error
  );

  process.exit(1);

});