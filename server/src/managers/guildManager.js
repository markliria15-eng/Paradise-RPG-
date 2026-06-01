const guildRepo = require("../repositories/guildRepository");

class GuildManager {
  constructor() {
    this.invites = new Map();
  }

  async createGuild(ownerPlayer, name) {
    const existing = await guildRepo.findByName(name);
    if (existing) {
      throw new Error("Nome de guilda indisponivel.");
    }
    const guild = await guildRepo.createGuild({
      ownerId: ownerPlayer.characterId,
      name
    });
    ownerPlayer.guildId = guild.id;
    return guild;
  }

  invite(inviterId, targetId) {
    this.invites.set(`${targetId}`, {
      inviterId,
      targetId,
      at: Date.now()
    });
  }

  popInvite(targetId) {
    const key = `${targetId}`;
    const invite = this.invites.get(key) || null;
    this.invites.delete(key);
    return invite;
  }

  async joinByInvite(targetPlayer, guildId) {
    await guildRepo.addMember(guildId, targetPlayer.characterId, "member");
    targetPlayer.guildId = guildId;
  }

  async guildInfoByCharacter(characterId) {
    const guild = await guildRepo.guildOfCharacter(characterId);
    if (!guild) return null;
    const members = await guildRepo.members(guild.id);
    return { guild, members };
  }
}

module.exports = GuildManager;

