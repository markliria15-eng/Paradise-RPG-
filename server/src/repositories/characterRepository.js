const pool = require("../db/pool");

const START_BY_CLASS = {
  Guerreiro: { hp: 150, mana: 40 },
  Mago: { hp: 90, mana: 150 },
  Arqueiro: { hp: 110, mana: 80 }
};

function formatSkills(row) {
  const required = (level) => 100 + Number(level || 10) * 25;
  const fightingLevel = Number(row.fighting_level || 10);
  const distanceLevel = Number(row.distance_level || 10);
  const magicLevel = Number(row.magic_level || 10);
  const protectionLevel = Number(row.protection_level || 10);
  return {
    fighting: { name: "Lutando", level: fightingLevel, xp: Number(row.fighting_xp || 0), xp_required: required(fightingLevel) },
    distance: { name: "Distancia", level: distanceLevel, xp: Number(row.distance_xp || 0), xp_required: required(distanceLevel) },
    magic: { name: "Magica", level: magicLevel, xp: Number(row.magic_xp || 0), xp_required: required(magicLevel) },
    protection: { name: "Protecao", level: protectionLevel, xp: Number(row.protection_xp || 0), xp_required: required(protectionLevel) }
  };
}

function withSkills(row) {
  if (!row) return null;
  const character = {
    id: row.id,
    account_id: row.account_id,
    name: row.name,
    class: row.class,
    level: row.level,
    xp: row.xp,
    hp: row.hp,
    mana: row.mana,
    gold: row.gold,
    map: row.map,
    pos_x: row.pos_x,
    pos_y: row.pos_y
  };
  character.skills = formatSkills(row);
  return character;
}

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
  return findById(character.id);
}

async function findById(characterId) {
  const result = await pool.query(
    `SELECT c.id, c.account_id, c.name, c.class, c.level, c.xp, c.hp, c.mana, c.gold, c.map, c.pos_x, c.pos_y,
            s.fighting_level, s.fighting_xp, s.distance_level, s.distance_xp,
            s.magic_level, s.magic_xp, s.protection_level, s.protection_xp
     FROM characters c
     LEFT JOIN skills s ON s.character_id = c.id
     WHERE c.id = $1`,
    [characterId]
  );
  return withSkills(result.rows[0]);
}

async function findByName(name) {
  const result = await pool.query("SELECT id, name FROM characters WHERE name = $1", [name]);
  return result.rows[0] || null;
}

async function listByAccount(accountId) {
  const result = await pool.query(
    `SELECT c.id, c.account_id, c.name, c.class, c.level, c.xp, c.hp, c.mana, c.gold, c.map, c.pos_x, c.pos_y,
            s.fighting_level, s.fighting_xp, s.distance_level, s.distance_xp,
            s.magic_level, s.magic_xp, s.protection_level, s.protection_xp
     FROM characters c
     LEFT JOIN skills s ON s.character_id = c.id
     WHERE c.account_id = $1
     ORDER BY c.id ASC`,
    [accountId]
  );
  return result.rows.map(withSkills);
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
