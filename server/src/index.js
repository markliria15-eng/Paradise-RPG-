const express = require("express");
const http = require("http");
const path = require("path");
const cors = require("cors");
const helmet = require("helmet");
const compression = require("compression");
const morgan = require("morgan");

const config = require("./config");
const logger = require("./utils/logger");
const pool = require("./db/pool");
const authRoutes = require("./http/authRoutes");
const WorldService = require("./services/worldService");
const WsGateway = require("./net/wsGateway");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForDatabase() {
  let lastError;
  for (let attempt = 1; attempt <= config.dbStartupAttempts; attempt += 1) {
    try {
      await pool.query("SELECT 1");
      logger.info("Banco conectado.");
      return;
    } catch (err) {
      lastError = err;
      logger.warn(
        `Banco indisponivel na tentativa ${attempt}/${config.dbStartupAttempts}: ${err.message}`
      );
      if (attempt < config.dbStartupAttempts) {
        await sleep(config.dbStartupRetryDelayMs);
      }
    }
  }
  throw lastError;
}

async function main() {
  const app = express();
  app.use(helmet());
  app.use(compression());
  app.use(cors({ origin: config.clientOrigin }));
  app.use(express.json({ limit: "256kb" }));
  app.use(morgan("dev"));

  app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "paradise-rpg-server" });
  });

  app.get("/download/android", (_req, res) => {
    res.redirect(302, config.androidDownloadUrl);
  });

  app.get("/download/status", (_req, res) => {
    res.json({
      ok: true,
      android: config.androidDownloadUrl
    });
  });

  app.use(
    "/patch/files",
    express.static(path.resolve(__dirname, "../public/patches/data"), {
      etag: true,
      immutable: true,
      maxAge: "1h"
    })
  );

  app.get("/patch/manifest", (_req, res) => {
    res.setHeader("Cache-Control", "no-store");
    res.sendFile(path.resolve(__dirname, "../public/patches/manifest.json"));
  });

  await waitForDatabase();
  const world = new WorldService();
  await world.bootstrapMmoSystems();

  app.get("/world/status", (_req, res) => {
    res.json({ ok: true, ...world.status() });
  });
  app.use("/auth", authRoutes);

  const server = http.createServer(app);
  server.listen(config.httpPort, config.httpHost, () => {
    logger.info(`HTTP online em http://${config.httpHost}:${config.httpPort}`);
  });

  const wsOptions =
    config.wsMode === "separate"
      ? { port: config.wsPort, worldService: world }
      : { server, path: config.wsPath, worldService: world };
  const ws = new WsGateway(wsOptions);
  ws.start();
  if (config.wsMode === "separate") {
    logger.info(`WebSocket MMO online em ws://${config.httpHost}:${config.wsPort}`);
  } else {
    logger.info(`WebSocket MMO online em ws://${config.httpHost}:${config.httpPort}${config.wsPath}`);
  }

  setInterval(async () => {
    try {
      await world.tick();
    } catch (err) {
      logger.error("Erro no tick do mundo", err);
    }
  }, config.worldTickMs);
}

main().catch((err) => {
  logger.error("Falha fatal ao subir servidor", err);
  process.exit(1);
});
