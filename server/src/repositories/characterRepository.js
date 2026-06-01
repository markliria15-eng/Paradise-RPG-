const pool = require("../db/pool");

const START_BY_CLASS = {
  Guerreiro: { hp: 150, mana: 40 },
  Mago: { hp: 90, mana: 150 },
  Arqueiro: { hp: 110, mana: 80 }
};

async function createCharacter({ accountId, name, className }) {
  const start = START_BY_CLASS[className] || START_BY_CLASS.Guerreiro;
  const sql = `
    INSERT INTO characters (account_id, name, class, hp, mana)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING id, account_id, name, class, level, xp, hp, mana, gold, map, pos_x, pos_y
  `;
  const result = await pool.query(sql, [accountId, name, className, start.hp, start.mana]);
  const character = result.rows[0];
  await pool.query("INSERT INTO skills (character_id) VALUES ($1) ON CONFLICT (character_id) DO NOTHING", [character.id]);
  await pool.query("INSERT INTO equipment (character_id) VALUES ($1) ON CONFLICT (character_id) DO NOTHING", [character.id]);
  return character;
}

async function findById(characterId) {
  const result = await pool.query(
    "SELECT id, account_id, name, class, level, xp, hp, mana, gold, map, pos_x, pos_y FROM characters WHERE id = $1",
    [characterId]
  );
  return result.rows[0] || null;
}

async function findByName(name) {
  const result = await pool.query("SELECT id, name FROM characters WHERE name = $1", [name]);
  return result.rows[0] || null;
}

async function listByAccount(accountId) {
  const result = await pool.query(
    "SELECT id, account_id, name, class, level, xp, hp, mana, gold, map, pos_x, pos_y FROM characters WHERE account_id = $1 ORDER BY id ASC",
    [accountId]
  );
  return result.rows;
}

async function upsertState(state) {
  const sql = `
    UPDATE characters
    SET level = $2, xp = $3, hp = $4, mana = $5, gold = $6, map = $7, pos_x = $8, pos_y = $9, updated_at = NOW()
    WHERE id = $1
  `;
  await pool.query(sql, [
    state.id,
    state.level,
    state.xp,
    state.hp,
    state.mana,
    state.gold,
    state.map,
    state.pos.x,
    state.pos.y
  ]);
}

async function saveSkills(characterId, skills) {
  const sql = `
    UPDATE skills
    SET fighting_level = $2,
        fighting_xp = $3,
        distance_level = $4,
        distance_xp = $5,
        magic_level = $6,
        magic_xp = $7,
        protection_level = $8,
        protection_xp = $9,
        updated_at = NOW()
    WHERE character_id = $1
  `;
  await pool.query(sql, [
    characterId,
    skills.fighting.level,
    skills.fighting.xp,
    skills.distance.level,
    skills.distance.xp,
    skills.magic.level,
    skills.magic.xp,
    skills.protection.level,
    skills.protection.xp
  ]);
}

module.exports = {
  createCharacter,
  findById,
  findByName,
  listByAccount,
  upsertState,
  saveSkills
};

