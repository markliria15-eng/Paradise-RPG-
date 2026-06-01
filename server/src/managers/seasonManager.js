const { loadProjectJson } = require("../utils/jsonLoader");
const mmoRepo = require("../repositories/mmoRepository");
const pool = require("../db/pool");

class SeasonManager {
  constructor() {
    this.definitions = loadProjectJson("data/mmo_seasons.json");
  }

  async bootstrapDefinitions() {
    for (const season of this.definitions) {
      await mmoRepo.upsertSeasonDefinition(season);
    }
  }

  async activeSeason() {
    return mmoRepo.getActiveSeason();
  }

  xpRequired(level) {
    return 120 + level * 30;
  }

  async addXp(characterId, deltaXp) {
    const season = await this.activeSeason();
    if (!season) return null;
    await mmoRepo.addSeasonXp(characterId, season.id, deltaXp);
    const progress = await mmoRepo.getSeasonProgress(characterId, season.id);
    let level = Number(progress.level);
    let xp = Number(progress.xp);
    const messages = [];
    while (xp >= this.xpRequired(level)) {
      xp -= this.xpRequired(level);
      level += 1;
      messages.push(`Passe da temporada subiu para nivel ${level}!`);
    }
    if (level !== Number(progress.level) || xp !== Number(progress.xp)) {
      await pool.query(
        "UPDATE season_progress SET level = $3, xp = $4 WHERE character_id = $1 AND season_id = $2",
        [characterId, season.id, level, xp]
      );
    }
    return { season, level, xp, messages };
  }
}

module.exports = SeasonManager;
