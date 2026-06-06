const { Pool } = require("pg");
const config = require("../config");

const baseOptions = {
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: config.dbConnectionTimeoutMs
};

const poolOptions = config.db.url
  ? {
      ...baseOptions,
      connectionString: config.db.url,
      ssl: config.db.ssl ? { rejectUnauthorized: false } : undefined
    }
  : {
      ...baseOptions,
      host: config.db.host,
      port: config.db.port,
      database: config.db.database,
      user: config.db.user,
      password: config.db.password,
      ssl: config.db.ssl ? { rejectUnauthorized: false } : undefined
    };

const pool = new Pool(poolOptions);

pool.on("error", (err) => {
  console.error("[db] erro inesperado no pool:", err);
});

module.exports = pool;
