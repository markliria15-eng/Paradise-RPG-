const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "../../..");
const dataDir = path.join(repoRoot, "data");
const outputDir = path.join(repoRoot, "server", "public", "patches");
const outputDataDir = path.join(outputDir, "data");

const patchFiles = [
  "armor_sets_manifest.json",
  "classes.json",
  "enemies.json",
  "equipment_slots.json",
  "items.json",
  "maps.json",
  "mmo_achievements.json",
  "mmo_crafting_recipes.json",
  "mmo_dungeons.json",
  "mmo_mounts.json",
  "mmo_pets.json",
  "mmo_professions.json",
  "mmo_seasons.json",
  "quests.json",
  "recipes.json",
  "skills.json"
];

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

fs.mkdirSync(outputDataDir, { recursive: true });
const files = [];

for (const fileName of patchFiles) {
  const source = path.join(dataDir, fileName);
  if (!fs.existsSync(source)) {
    throw new Error(`Arquivo de dados nao encontrado: ${source}`);
  }
  const buffer = fs.readFileSync(source);
  fs.writeFileSync(path.join(outputDataDir, fileName), buffer);
  files.push({
    path: `data/${fileName}`,
    url: `/patch/files/${fileName}`,
    sha256: sha256(buffer),
    size: buffer.length
  });
}

const manifest = {
  ok: true,
  game: "Paradise RPG",
  channel: "beta",
  version: process.env.PATCH_VERSION || new Date().toISOString().slice(0, 10).replaceAll("-", "."),
  min_app_version: "0.1.5",
  generated_at: new Date().toISOString(),
  files
};

fs.writeFileSync(path.join(outputDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Patch manifest gerado com ${files.length} arquivos.`);
