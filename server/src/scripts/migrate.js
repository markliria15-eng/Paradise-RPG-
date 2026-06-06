const fs = require("fs");
const path = require("path");
const { Client } = require("pg");
const config = require("../config");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function clientOptions() {
  const ssl = config.db.ssl ? { rejectUnauthorized: false } : undefined;
  const base = {
    connectionTimeoutMillis: config.dbConnectionTimeoutMs,
    statement_timeout: 60000,
    query_timeout: 60000,
    ssl
  };

  if (config.db.url) {
    return {
      ...base,
      connectionString: config.db.url
    };
  }

  return {
    ...base,
    host: config.db.host,
    port: config.db.port,
    database: config.db.database,
    user: config.db.user,
    password: config.db.password
  };
}

async function applySchema(schema) {
  const client = new Client(clientOptions());
  try {
    await client.connect();
    await client.query(schema);
  } finally {
    await client.end().catch(() => {});
  }
}

async function run() {
  const schemaPath = path.resolve(__dirname, "../../../database/schema.sql");
  const schema = fs.readFileSync(schemaPath, "utf8");

  let lastError;
  for (let attempt = 1; attempt <= config.dbMigrateAttempts; attempt += 1) {
    try {
      console.log(`[db] aplicando schema (${attempt}/${config.dbMigrateAttempts})...`);
      await applySchema(schema);
      console.log("[db] schema aplicado com sucesso.");
      return;
    } catch (err) {
      lastError = err;
      console.error(
        `[db] falha ao aplicar schema (${attempt}/${config.dbMigrateAttempts}): ${err.message}`
      );
      if (attempt < config.dbMigrateAttempts) {
        await sleep(config.dbMigrateRetryDelayMs);
      }
    }
  }

  throw lastError;
}

run().catch((err) => {
  console.error("[db] schema nao foi aplicado depois de varias tentativas:", err.message);
  process.exit(1);
});
