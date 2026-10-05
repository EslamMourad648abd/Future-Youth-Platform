/**
 * 🚀 predeploy.js
 * This script auto-bumps Flutter web build cache version
 * so browsers always load the newest version after deploy.
 */

import fs from "fs";
import path from "path";

const indexPath = path.resolve("build/web/index.html");
let indexContent = fs.readFileSync(indexPath, "utf8");

// 🧠 Generate a version string based on timestamp
const version = new Date().toISOString().replace(/[-T:.Z]/g, "");
const pattern = /flutter_bootstrap\.js(\?v=\d+)?/;

// 🧩 Replace or add version parameter
indexContent = indexContent.replace(pattern, `flutter_bootstrap.js?v=${version}`);

fs.writeFileSync(indexPath, indexContent, "utf8");
console.log(`✅ Added cache-busting version tag: v=${version}`);

if (!fs.existsSync(indexPath)) {
  console.error("❌ Flutter web build not found. Run `flutter build web` first.");
  process.exit(1);
}

let html = fs.readFileSync(indexPath, "utf8");

// Add or update cache-busting version tag in flutter_bootstrap.js
const versionTag = `v=${Date.now()}`;
html = html.replace(
  /flutter_bootstrap\.js(\?v=\d+)?/,
  `flutter_bootstrap.js?${versionTag}`
);

fs.writeFileSync(indexPath, html);
console.log("✅ Cache-busting tag updated in index.html:", versionTag);
