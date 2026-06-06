const path = require("path");
const dotenv = require("dotenv");

dotenv.config({ path: path.resolve(__dirname, "../.env") });

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

module.exports = {
  env: process.env.NODE_ENV || "development",
  httpPort: intEnv("PORT", 8080),
  wsPort: intEnv("WS_PORT", 8081),
  wsMode: process.env.WS_MODE || "shared",
  wsPath: process.env.WS_PATH || "/ws",
  jwtSecret: process.env.JWT_SECRET || "dev-secret",
  jwtExpires: process.env.JWT_EXPIRES || "7d",
  clientOrigin: process.env.CLIENT_ORIGIN || "*",
  db: {
    url: process.env.DATABASE_URL || "",
    ssl: String(process.env.DB_SSL || "").toLowerCase() === "true",
    host: process.env.DB_HOST || "127.0.0.1",
    port: intEnv("DB_PORT", 5432),
    database: process.env.DB_NAME || "arcadia_mmo",
    user: process.env.DB_USER || "arcadia",
    password: process.env.DB_PASSWORD || "arcadia123"
  },
  saveIntervalMs: intEnv("SAVE_INTERVAL_MS", 20000),
  worldTickMs: intEnv("WORLD_TICK_MS", 100),
  chatFloodWindowMs: intEnv("CHAT_FLOOD_WINDOW_MS", 4000),
  chatFloodMaxMessages: intEnv("CHAT_FLOOD_MAX_MESSAGES", 5)
};
