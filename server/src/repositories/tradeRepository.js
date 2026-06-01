const pool = require("../db/pool");

async function appendTradeLog({ actorA, actorB, payload }) {
  await pool.query(
    "INSERT INTO trade_logs (actor_a, actor_b, payload) VALUES ($1, $2, $3::jsonb)",
    [actorA, actorB, JSON.stringify(payload)]
  );
}

module.exports = { appendTradeLog };

