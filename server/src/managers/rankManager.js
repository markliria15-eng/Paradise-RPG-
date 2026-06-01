const pool = require("../db/pool");
const mmoRepo = require("../repositories/mmoRepository");

class RankManager {
  constructor() {
    this.lastComputedAt = 0;
    this.computeEveryMs = 10 * 60 * 1000;
  }

  async computeIfNeeded() {
    const now = Date.now();
    if (now - this.lastComputedAt < this.computeEveryMs) return;
    this.lastComputedAt = now;
    await this.computeAll();
  }

  async computeAll() {
    const [topLevel, topGold, topFighting, topMagic, topDistance, topProtection] = await Promise.all([
      this._query(`
        SELECT c.id AS character_id, c.name, c.level AS score
        FROM characters c
        ORDER BY c.level DESC, c.xp DESC
        LIMIT 100
      `),
      this._query(`
        SELECT c.id AS character_id, c.name, c.gold AS score
        FROM characters c
        ORDER BY c.gold DESC
        LIMIT 100
      `),
      this._query(`
        SELECT c.id AS character_id, c.name, s.fighting_level AS score
        FROM skills s
        JOIN characters c ON c.id = s.character_id
        ORDER BY s.fighting_level DESC, s.fighting_xp DESC
        LIMIT 100
      `),
      this._query(`
        SELECT c.id AS character_id, c.name, s.magic_level AS score
        FROM skills s
        JOIN characters c ON c.id = s.character_id
        ORDER BY s.magic_level DESC, s.magic_xp DESC
        LIMIT 100
      `),
      this._query(`
        SELECT c.id AS character_id, c.name, s.distance_level AS score
        FROM skills s
        JOIN characters c ON c.id = s.character_id
        ORDER BY s.distance_level DESC, s.distance_xp DESC
        LIMIT 100
      `),
      this._query(`
        SELECT c.id AS character_id, c.name, s.protection_level AS score
        FROM skills s
        JOIN characters c ON c.id = s.character_id
        ORDER BY s.protection_level DESC, s.protection_xp DESC
        LIMIT 100
      `)
    ]);

    await Promise.all([
      mmoRepo.setRankCache("top_level", topLevel),
      mmoRepo.setRankCache("top_gold", topGold),
      mmoRepo.setRankCache("top_fighting", topFighting),
      mmoRepo.setRankCache("top_magic", topMagic),
      mmoRepo.setRankCache("top_distance", topDistance),
      mmoRepo.setRankCache("top_protection", topProtection)
    ]);
  }

  async get(rankKey) {
    const cache = await mmoRepo.getRankCache(rankKey);
    return cache ? cache.payload : [];
  }

  async _query(sql) {
    const result = await pool.query(sql);
    return result.rows;
  }
}

module.exports = RankManager;

