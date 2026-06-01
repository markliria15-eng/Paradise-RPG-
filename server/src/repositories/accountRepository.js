const pool = require("../db/pool");

async function createAccount({ username, email, passwordHash }) {
  const sql = `
    INSERT INTO accounts (username, email, password_hash)
    VALUES ($1, $2, $3)
    RETURNING id, username, email, banned, vip, premium_days, created_at
  `;
  const result = await pool.query(sql, [username, email, passwordHash]);
  return result.rows[0];
}

async function findByEmail(email) {
  const result = await pool.query(
    "SELECT id, username, email, password_hash, banned, vip, premium_days FROM accounts WHERE email = $1",
    [email]
  );
  return result.rows[0] || null;
}

async function findByUsername(username) {
  const result = await pool.query(
    "SELECT id, username, email, password_hash, banned, vip, premium_days FROM accounts WHERE username = $1",
    [username]
  );
  return result.rows[0] || null;
}

async function touchLastLogin(accountId) {
  await pool.query("UPDATE accounts SET last_login = NOW() WHERE id = $1", [accountId]);
}

module.exports = {
  createAccount,
  findByEmail,
  findByUsername,
  touchLastLogin
};

