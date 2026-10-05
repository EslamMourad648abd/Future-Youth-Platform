import { google } from "googleapis";

const auth = new google.auth.GoogleAuth({
  scopes: [
    "https://www.googleapis.com/auth/drive.readonly",
  ],
});

const drive = google.drive({
  version: "v3",
  auth,
});

export default drive;