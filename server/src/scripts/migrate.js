const fs = require("fs");
const path = require("path");
const pool = require("../db/pool");

async function run() {
  const schemaPath = path.resolve(__dirname, "../../../database/schema.sql");
  const schema = fs.readFileSync(schemaPath, "utf8");
  await pool.query(schema);
  console.log("[db] schema aplicado com sucesso.");
  await pool.end();
}

run().catch((err) => {
  console.error("[db] falha ao aplicar schema:", err.message);
  process.exit(1);
});
