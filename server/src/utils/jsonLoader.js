const fs = require("fs");
const path = require("path");

function loadProjectJson(relativePathFromRoot) {
  const fullPath = path.resolve(__dirname, "../../../", relativePathFromRoot);
  const text = fs.readFileSync(fullPath, "utf8");
  return JSON.parse(text);
}

module.exports = { loadProjectJson };

