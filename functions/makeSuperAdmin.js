// makeSuperAdmin.js

import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import serviceAccount from "./bbc-api-tool-firebase-adminsdk-fbsvc-344ab63826.json" with { type: "json" };


initializeApp({
  credential: cert(serviceAccount),
});


const auth = getAuth();


const email = "eslam.mourad@bevatel.com"; // change if needed


async function makeSuperAdmin() {

  try {

    const user = await auth.getUserByEmail(email);


    await auth.setCustomUserClaims(
      user.uid,
      {
        role: "superadmin"
      }
    );


    console.log(
      `✅ ${email} is now SUPERADMIN`
    );


    console.log(
      "UID:",
      user.uid
    );


    process.exit(0);


  } catch(error) {

    console.error(
      "❌ Failed:",
      error
    );

    process.exit(1);

  }

}


makeSuperAdmin();