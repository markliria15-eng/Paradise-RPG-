const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");

class AchievementManager {
  constructor() {
    this.definitions = loadProjectJson("data/mmo_achievements.json");
  }

  async bootstrapDefinitions() {
    for (const def of this.definitions) {
      await mmoRepo.upsertAchievementDefinition(def);
    }
  }

  async progress(characterId, code, delta) {
    const ach = await mmoRepo.findAchievementByCode(code);
    if (!ach) throw new Error("Conquista nao encontrada.");
    await mmoRepo.upsertAchievementProgress(characterId, ach.id, delta);
    const all = await mmoRepo.listCharacterAchievements(characterId);
    const current = all.find((row) => row.code === code);
    if (current && !current.completed && Number(current.progress) >= Number(current.objective)) {
      await mmoRepo.markAchievementCompleted(characterId, ach.id);
      return { completed: true, achievement: current };
    }
    return { completed: false, achievement: current };
  }

  async list(characterId) {
    return mmoRepo.listCharacterAchievements(characterId);
  }
}

module.exports = AchievementManager;

