// scripts/predeploy.js
import fs from "fs";
const indexPath = "./build/web/index.html";

let indexContent = fs.readFileSync(indexPath, "utf8");

// Add version tag to flutter_bootstrap.js
indexContent = indexContent.replace(
  /flutter_bootstrap\.js(\?v=\d+\.\d+\.\d+)?/,
  `flutter_bootstrap.js?v=${Date.now()}`
);

fs.writeFileSync(indexPath, indexContent, "utf8");
console.log("✅ Cache-busting tag applied successfully");
