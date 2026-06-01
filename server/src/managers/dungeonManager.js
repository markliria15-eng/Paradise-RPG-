const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");

class DungeonManager {
  constructor() {
    this.definitions = loadProjectJson("data/mmo_dungeons.json");
    this.activeByRunId = new Map();
  }

  async bootstrapDefinitions() {
    for (const d of this.definitions) {
      await mmoRepo.upsertDungeonDefinition(d);
    }
  }

  async list() {
    return mmoRepo.listDungeons();
  }

  async startRun({ dungeonCode, leader, members }) {
    const dungeon = await mmoRepo.findDungeonByCode(dungeonCode);
    if (!dungeon) throw new Error("Dungeon nao encontrada.");
    if (leader.level < dungeon.min_level) throw new Error("Level minimo nao atingido.");
    if (members.length > dungeon.max_party_size) throw new Error("Party acima do limite da dungeon.");

    const lastRun = await mmoRepo.lastDungeonRunByCharacter(dungeon.id, leader.characterId);
    if (lastRun && lastRun.ended_at) {
      const cooldownMs = Number(dungeon.reward_cooldown_hours) * 3600 * 1000;
      const elapsed = Date.now() - new Date(lastRun.ended_at).getTime();
      if (elapsed < cooldownMs) {
        throw new Error("Cooldown de recompensa da dungeon ativo.");
      }
    }

    const run = await mmoRepo.createDungeonRun({
      dungeonId: dungeon.id,
      leaderCharacterId: leader.characterId,
      members: members.map((p) => p.characterId)
    });
    this.activeByRunId.set(run.id, {
      ...run,
      timeLimitEndsAt: Date.now() + Number(dungeon.time_limit_seconds) * 1000
    });
    return { run, dungeon };
  }

  async finishRun(runId, rewardClaimed = true) {
    this.activeByRunId.delete(runId);
    return mmoRepo.finishDungeonRun(runId, rewardClaimed);
  }

  tick() {
    const now = Date.now();
    const expired = [];
    for (const run of this.activeByRunId.values()) {
      if (now >= run.timeLimitEndsAt) expired.push(run.id);
    }
    return expired;
  }
}

module.exports = DungeonManager;

