// checkRole.js

import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import serviceAccount from "./bbc-api-tool-firebase-adminsdk-fbsvc-344ab63826.json" with { type: "json" };


initializeApp({
  credential: cert(serviceAccount),
});


const auth = getAuth();


async function checkRole() {

  try {

    const user = await auth.getUserByEmail(
      "eslam.mourad@bevatel.com"
    );


    console.log("Email:", user.email);

    console.log(
      "Claims:",
      user.customClaims
    );


    process.exit(0);


  } catch(error) {

    console.error(
      "❌ Error:",
      error
    );

    process.exit(1);

  }

}


checkRole();