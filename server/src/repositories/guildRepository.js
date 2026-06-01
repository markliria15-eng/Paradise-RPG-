const pool = require("../db/pool");

async function createGuild({ ownerId, name }) {
  const guild = await pool.query(
    "INSERT INTO guilds (name, owner_id) VALUES ($1, $2) RETURNING id, name, owner_id, level, motd, created_at",
    [name, ownerId]
  );
  await pool.query(
    "INSERT INTO guild_members (guild_id, character_id, role) VALUES ($1, $2, 'leader')",
    [guild.rows[0].id, ownerId]
  );
  return guild.rows[0];
}

async function findByName(name) {
  const result = await pool.query("SELECT id, name, owner_id, level, motd FROM guilds WHERE name = $1", [name]);
  return result.rows[0] || null;
}

async function findById(guildId) {
  const result = await pool.query("SELECT id, name, owner_id, level, motd FROM guilds WHERE id = $1", [guildId]);
  return result.rows[0] || null;
}

async function members(guildId) {
  const result = await pool.query(
    `
      SELECT gm.character_id, gm.role, c.name, c.level
      FROM guild_members gm
      JOIN characters c ON c.id = gm.character_id
      WHERE gm.guild_id = $1
      ORDER BY gm.joined_at ASC
    `,
    [guildId]
  );
  return result.rows;
}

async function addMember(guildId, characterId, role = "member") {
  await pool.query(
    "INSERT INTO guild_members (guild_id, character_id, role) VALUES ($1, $2, $3) ON CONFLICT (guild_id, character_id) DO NOTHING",
    [guildId, characterId, role]
  );
}

async function removeMember(guildId, characterId) {
  await pool.query("DELETE FROM guild_members WHERE guild_id = $1 AND character_id = $2", [guildId, characterId]);
}

async function guildOfCharacter(characterId) {
  const result = await pool.query(
    `
      SELECT g.id, g.name, g.owner_id, g.level, g.motd, gm.role
      FROM guild_members gm
      JOIN guilds g ON g.id = gm.guild_id
      WHERE gm.character_id = $1
      LIMIT 1
    `,
    [characterId]
  );
  return result.rows[0] || null;
}

module.exports = {
  createGuild,
  findByName,
  findById,
  members,
  addMember,
  removeMember,
  guildOfCharacter
};

