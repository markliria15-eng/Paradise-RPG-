const characterRepo = require("../repositories/characterRepository");

class SaveManager {
  async savePlayerState(playerState) {
    await characterRepo.upsertState({
      id: playerState.characterId,
      level: playerState.level,
      xp: playerState.xp,
      hp: playerState.hp,
      mana: playerState.mana,
      gold: playerState.gold,
      map: playerState.map,
      pos: playerState.pos
    });
    if (playerState.skills) {
      await this.saveSkills(playerState.characterId, playerState.skills);
    }
  }

  async saveSkills(characterId, skills) {
    await characterRepo.saveSkills(characterId, skills);
  }

  async saveAll(players) {
    for (const player of players) {
      await this.savePlayerState(player);
    }
  }
}

module.exports = SaveManager;
