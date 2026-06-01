const pool = require("../db/pool");

async function run() {
  const result = await pool.query("SELECT NOW() AS now");
  console.log("[db] conectado com sucesso:", result.rows[0].now);
  await pool.end();
}

run().catch((err) => {
  console.error("[db] falha:", err.message);
  process.exit(1);
});

