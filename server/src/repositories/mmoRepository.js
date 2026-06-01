const pool = require("../db/pool");

async function ensureProfessionRow(characterId) {
  await pool.query("INSERT INTO professions (character_id) VALUES ($1) ON CONFLICT (character_id) DO NOTHING", [characterId]);
}

async function getProfessions(characterId) {
  await ensureProfessionRow(characterId);
  const result = await pool.query("SELECT * FROM professions WHERE character_id = $1", [characterId]);
  return result.rows[0] || null;
}

async function updateProfession(characterId, key, level, xp) {
  const colLevel = `${key}_level`;
  const colXp = `${key}_xp`;
  await pool.query(
    `UPDATE professions SET ${colLevel} = $2, ${colXp} = $3, updated_at = NOW() WHERE character_id = $1`,
    [characterId, level, xp]
  );
}

async function listMarket(filters = {}) {
  const values = [];
  let where = "WHERE status = 'active'";
  if (filters.category) {
    values.push(filters.category);
    where += ` AND category = $${values.length}`;
  }
  if (filters.rarity) {
    values.push(filters.rarity);
    where += ` AND rarity = $${values.length}`;
  }
  if (filters.itemId) {
    values.push(filters.itemId);
    where += ` AND item_id ILIKE $${values.length}`;
    values[values.length - 1] = `%${filters.itemId}%`;
  }
  const result = await pool.query(
    `SELECT id, seller_character_id, item_id, quantity, price, rarity, category, created_at
     FROM market_listings ${where}
     ORDER BY created_at DESC
     LIMIT 100`,
    values
  );
  return result.rows;
}

async function createListing({ sellerCharacterId, itemId, quantity, price, rarity, category }) {
  const result = await pool.query(
    `INSERT INTO market_listings
      (seller_character_id, item_id, quantity, price, rarity, category, status)
     VALUES ($1,$2,$3,$4,$5,$6,'active')
     RETURNING id, seller_character_id, item_id, quantity, price, rarity, category, status, created_at`,
    [sellerCharacterId, itemId, quantity, price, rarity, category]
  );
  return result.rows[0];
}

async function findListingById(listingId) {
  const result = await pool.query(
    "SELECT * FROM market_listings WHERE id = $1 LIMIT 1",
    [listingId]
  );
  return result.rows[0] || null;
}

async function closeListing(listingId, status = "sold") {
  const result = await pool.query(
    "UPDATE market_listings SET status = $2, sold_at = NOW() WHERE id = $1 RETURNING *",
    [listingId, status]
  );
  return result.rows[0] || null;
}

async function addGold(characterId, amount) {
  await pool.query("UPDATE characters SET gold = gold + $2, updated_at = NOW() WHERE id = $1", [characterId, amount]);
}

async function removeGold(characterId, amount) {
  const result = await pool.query(
    "UPDATE characters SET gold = gold - $2, updated_at = NOW() WHERE id = $1 AND gold >= $2 RETURNING id, gold",
    [characterId, amount]
  );
  return result.rows[0] || null;
}

async function getCharacterGold(characterId) {
  const result = await pool.query("SELECT id, gold FROM characters WHERE id = $1", [characterId]);
  return result.rows[0] || null;
}

async function getCharacterInventoryItem(characterId, itemId) {
  const result = await pool.query(
    "SELECT id, amount FROM inventory WHERE character_id = $1 AND item_id = $2 LIMIT 1",
    [characterId, itemId]
  );
  return result.rows[0] || null;
}

async function upsertPetDefinition({ code, name, rarity, baseBonus }) {
  await pool.query(
    `INSERT INTO pets (code, name, rarity, base_bonus)
     VALUES ($1,$2,$3,$4::jsonb)
     ON CONFLICT(code) DO UPDATE
     SET name = EXCLUDED.name,
         rarity = EXCLUDED.rarity,
         base_bonus = EXCLUDED.base_bonus`,
    [code, name, rarity, JSON.stringify(baseBonus || {})]
  );
}

async function listCharacterPets(characterId) {
  const result = await pool.query(
    `SELECT cp.id, cp.character_id, cp.level, cp.xp, cp.equipped,
            p.id AS pet_id, p.code, p.name, p.rarity, p.base_bonus, p.sprite
     FROM character_pets cp
     JOIN pets p ON p.id = cp.pet_id
     WHERE cp.character_id = $1
     ORDER BY cp.id ASC`,
    [characterId]
  );
  return result.rows;
}

async function grantPetByCode(characterId, code) {
  const pet = await pool.query("SELECT id, code FROM pets WHERE code = $1 LIMIT 1", [code]);
  if (!pet.rows[0]) throw new Error("Pet inexistente.");
  await pool.query(
    `INSERT INTO character_pets (character_id, pet_id)
     VALUES ($1, $2)
     ON CONFLICT(character_id, pet_id) DO NOTHING`,
    [characterId, pet.rows[0].id]
  );
}

async function setPetEquipped(characterId, characterPetId) {
  await pool.query("UPDATE character_pets SET equipped = FALSE WHERE character_id = $1", [characterId]);
  await pool.query("UPDATE character_pets SET equipped = TRUE WHERE character_id = $1 AND id = $2", [characterId, characterPetId]);
}

async function addPetXp(characterPetId, delta) {
  await pool.query("UPDATE character_pets SET xp = xp + $2 WHERE id = $1", [characterPetId, delta]);
}

async function updatePetLevel(characterPetId, level, xp) {
  await pool.query("UPDATE character_pets SET level = $2, xp = $3 WHERE id = $1", [characterPetId, level, xp]);
}

async function upsertMountDefinition({ code, name, rarity, speedBonus, extraBonus }) {
  await pool.query(
    `INSERT INTO mounts (code, name, rarity, speed_bonus, extra_bonus)
     VALUES ($1,$2,$3,$4,$5::jsonb)
     ON CONFLICT(code) DO UPDATE
     SET name = EXCLUDED.name,
         rarity = EXCLUDED.rarity,
         speed_bonus = EXCLUDED.speed_bonus,
         extra_bonus = EXCLUDED.extra_bonus`,
    [code, name, rarity, speedBonus, JSON.stringify(extraBonus || {})]
  );
}

async function listCharacterMounts(characterId) {
  const result = await pool.query(
    `SELECT cm.id, cm.character_id, cm.equipped,
            m.id AS mount_id, m.code, m.name, m.rarity, m.speed_bonus, m.extra_bonus
     FROM character_mounts cm
     JOIN mounts m ON m.id = cm.mount_id
     WHERE cm.character_id = $1
     ORDER BY cm.id ASC`,
    [characterId]
  );
  return result.rows;
}

async function grantMountByCode(characterId, code) {
  const mount = await pool.query("SELECT id FROM mounts WHERE code = $1 LIMIT 1", [code]);
  if (!mount.rows[0]) throw new Error("Montaria inexistente.");
  await pool.query(
    `INSERT INTO character_mounts (character_id, mount_id)
     VALUES ($1,$2)
     ON CONFLICT(character_id, mount_id) DO NOTHING`,
    [characterId, mount.rows[0].id]
  );
}

async function setMountEquipped(characterId, characterMountId) {
  await pool.query("UPDATE character_mounts SET equipped = FALSE WHERE character_id = $1", [characterId]);
  await pool.query("UPDATE character_mounts SET equipped = TRUE WHERE character_id = $1 AND id = $2", [characterId, characterMountId]);
}

async function addInventoryItem(characterId, itemId, amount) {
  await pool.query(
    `INSERT INTO inventory (character_id, item_id, amount)
     VALUES ($1,$2,$3)
     ON CONFLICT(character_id, item_id) DO UPDATE SET amount = inventory.amount + EXCLUDED.amount`,
    [characterId, itemId, amount]
  );
}

async function removeInventoryItem(characterId, itemId, amount) {
  const row = await getCharacterInventoryItem(characterId, itemId);
  if (!row || row.amount < amount) return false;
  await pool.query("UPDATE inventory SET amount = amount - $3 WHERE character_id = $1 AND item_id = $2", [characterId, itemId, amount]);
  await pool.query("DELETE FROM inventory WHERE character_id = $1 AND item_id = $2 AND amount <= 0", [characterId, itemId]);
  return true;
}

async function setRankCache(rankKey, payload) {
  await pool.query(
    `INSERT INTO rank_cache (rank_key, payload, computed_at)
     VALUES ($1, $2::jsonb, NOW())
     ON CONFLICT(rank_key) DO UPDATE SET payload = EXCLUDED.payload, computed_at = NOW()`,
    [rankKey, JSON.stringify(payload)]
  );
}

async function getRankCache(rankKey) {
  const result = await pool.query(
    "SELECT rank_key, payload, computed_at FROM rank_cache WHERE rank_key = $1 LIMIT 1",
    [rankKey]
  );
  return result.rows[0] || null;
}

async function upsertAchievementProgress(characterId, achievementId, delta) {
  await pool.query(
    `INSERT INTO character_achievements (character_id, achievement_id, progress)
     VALUES ($1, $2, $3)
     ON CONFLICT(character_id, achievement_id) DO UPDATE SET progress = character_achievements.progress + EXCLUDED.progress`,
    [characterId, achievementId, delta]
  );
}

async function upsertAchievementDefinition(def) {
  await pool.query(
    `INSERT INTO achievements (code, name, description, category, objective, reward)
     VALUES ($1,$2,$3,$4,$5,$6::jsonb)
     ON CONFLICT(code) DO UPDATE
     SET name = EXCLUDED.name,
         description = EXCLUDED.description,
         category = EXCLUDED.category,
         objective = EXCLUDED.objective,
         reward = EXCLUDED.reward`,
    [def.code, def.name, def.description, def.category, def.objective, JSON.stringify(def.reward || {})]
  );
}

async function findAchievementByCode(code) {
  const result = await pool.query(
    "SELECT id, code, name, description, category, objective, reward FROM achievements WHERE code = $1 LIMIT 1",
    [code]
  );
  return result.rows[0] || null;
}

async function listAchievements() {
  const result = await pool.query("SELECT id, code, name, description, category, objective, reward FROM achievements ORDER BY id ASC");
  return result.rows;
}

async function markAchievementCompleted(characterId, achievementId) {
  await pool.query(
    `UPDATE character_achievements
     SET completed = TRUE, completed_at = NOW()
     WHERE character_id = $1 AND achievement_id = $2`,
    [characterId, achievementId]
  );
}

async function listCharacterAchievements(characterId) {
  const result = await pool.query(
    `SELECT a.id AS achievement_id,
            COALESCE(ca.progress, 0) AS progress,
            COALESCE(ca.completed, FALSE) AS completed,
            COALESCE(ca.rewarded, FALSE) AS rewarded,
            a.code, a.name, a.description, a.category, a.objective, a.reward
     FROM achievements a
     LEFT JOIN character_achievements ca
       ON ca.achievement_id = a.id
      AND ca.character_id = $1
     ORDER BY a.id ASC`,
    [characterId]
  );
  return result.rows;
}

async function getActiveSeason() {
  const result = await pool.query(
    "SELECT id, code, name, starts_at, ends_at, active FROM seasons WHERE active = TRUE ORDER BY id DESC LIMIT 1"
  );
  return result.rows[0] || null;
}

async function upsertSeasonDefinition(def) {
  await pool.query(
    `INSERT INTO seasons (code, name, starts_at, ends_at, active)
     VALUES ($1,$2,$3,$4,$5)
     ON CONFLICT(code) DO UPDATE
     SET name = EXCLUDED.name,
         starts_at = EXCLUDED.starts_at,
         ends_at = EXCLUDED.ends_at,
         active = EXCLUDED.active`,
    [def.code, def.name, def.starts_at, def.ends_at, !!def.active]
  );
}

async function listSeasons() {
  const result = await pool.query("SELECT * FROM seasons ORDER BY id DESC");
  return result.rows;
}

async function ensureSeasonProgress(characterId, seasonId) {
  await pool.query(
    `INSERT INTO season_progress (character_id, season_id)
     VALUES ($1, $2)
     ON CONFLICT(character_id, season_id) DO NOTHING`,
    [characterId, seasonId]
  );
}

async function addSeasonXp(characterId, seasonId, deltaXp) {
  await ensureSeasonProgress(characterId, seasonId);
  await pool.query(
    "UPDATE season_progress SET xp = xp + $3 WHERE character_id = $1 AND season_id = $2",
    [characterId, seasonId, deltaXp]
  );
}

async function getSeasonProgress(characterId, seasonId) {
  await ensureSeasonProgress(characterId, seasonId);
  const result = await pool.query(
    "SELECT * FROM season_progress WHERE character_id = $1 AND season_id = $2",
    [characterId, seasonId]
  );
  return result.rows[0] || null;
}

async function setVip(accountId, days) {
  await pool.query(
    `UPDATE accounts
     SET vip_days = vip_days + $2,
         vip_active = TRUE,
         vip_expire_at = COALESCE(vip_expire_at, NOW()) + make_interval(days => $2),
         premium_days = premium_days + $2
     WHERE id = $1`,
    [accountId, days]
  );
}

async function getAccountVip(accountId) {
  const result = await pool.query(
    "SELECT id, vip, vip_days, vip_active, vip_expire_at, premium_days FROM accounts WHERE id = $1",
    [accountId]
  );
  return result.rows[0] || null;
}

async function createDungeonRun({ dungeonId, leaderCharacterId, members }) {
  const result = await pool.query(
    `INSERT INTO dungeon_runs (dungeon_id, leader_character_id, members, status)
     VALUES ($1, $2, $3::jsonb, 'active')
     RETURNING *`,
    [dungeonId, leaderCharacterId, JSON.stringify(members)]
  );
  return result.rows[0];
}

async function upsertDungeonDefinition(def) {
  await pool.query(
    `INSERT INTO dungeons (code, name, min_level, max_party_size, time_limit_seconds, reward_cooldown_hours)
     VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT(code) DO UPDATE
     SET name = EXCLUDED.name,
         min_level = EXCLUDED.min_level,
         max_party_size = EXCLUDED.max_party_size,
         time_limit_seconds = EXCLUDED.time_limit_seconds,
         reward_cooldown_hours = EXCLUDED.reward_cooldown_hours`,
    [def.code, def.name, def.min_level, def.max_party_size, def.time_limit_seconds, def.reward_cooldown_hours]
  );
}

async function findDungeonByCode(code) {
  const result = await pool.query("SELECT * FROM dungeons WHERE code = $1 LIMIT 1", [code]);
  return result.rows[0] || null;
}

async function listDungeons() {
  const result = await pool.query("SELECT * FROM dungeons ORDER BY id ASC");
  return result.rows;
}

async function finishDungeonRun(runId, rewardClaimed = true) {
  const result = await pool.query(
    `UPDATE dungeon_runs
     SET status = 'finished',
         ended_at = NOW(),
         reward_claimed = $2
     WHERE id = $1
     RETURNING *`,
    [runId, rewardClaimed]
  );
  return result.rows[0] || null;
}

async function lastDungeonRunByCharacter(dungeonId, characterId) {
  const result = await pool.query(
    `SELECT *
     FROM dungeon_runs
     WHERE dungeon_id = $1
       AND members @> $2::jsonb
     ORDER BY started_at DESC
     LIMIT 1`,
    [dungeonId, JSON.stringify([characterId])]
  );
  return result.rows[0] || null;
}

module.exports = {
  getProfessions,
  updateProfession,
  listMarket,
  createListing,
  findListingById,
  closeListing,
  addGold,
  removeGold,
  getCharacterGold,
  getCharacterInventoryItem,
  addInventoryItem,
  removeInventoryItem,
  upsertPetDefinition,
  listCharacterPets,
  grantPetByCode,
  setPetEquipped,
  addPetXp,
  updatePetLevel,
  upsertMountDefinition,
  listCharacterMounts,
  grantMountByCode,
  setMountEquipped,
  setRankCache,
  getRankCache,
  upsertAchievementDefinition,
  findAchievementByCode,
  listAchievements,
  upsertAchievementProgress,
  markAchievementCompleted,
  listCharacterAchievements,
  upsertSeasonDefinition,
  listSeasons,
  getActiveSeason,
  addSeasonXp,
  getSeasonProgress,
  setVip,
  getAccountVip,
  createDungeonRun,
  upsertDungeonDefinition,
  findDungeonByCode,
  listDungeons,
  finishDungeonRun,
  lastDungeonRunByCharacter
};
