const config = require("../config");
const AntiCheatManager = require("../managers/antiCheatManager");
const MapManager = require("../managers/mapManager");
const PlayerManager = require("../managers/playerManager");
const EntityManager = require("../managers/entityManager");
const ChatManager = require("../managers/chatManager");
const TradeManager = require("../managers/tradeManager");
const GuildManager = require("../managers/guildManager");
const PvpManager = require("../managers/pvpManager");
const CombatManager = require("../managers/combatManager");
const BossManager = require("../managers/bossManager");
const EventManager = require("../managers/eventManager");
const PartyManager = require("../managers/partyManager");
const SaveManager = require("../managers/saveManager");
const ProfessionManager = require("../managers/professionManager");
const CraftingManager = require("../managers/craftingManager");
const PetManager = require("../managers/petManager");
const MountManager = require("../managers/mountManager");
const DungeonManager = require("../managers/dungeonManager");
const RankManager = require("../managers/rankManager");
const MarketManager = require("../managers/marketManager");
const VipManager = require("../managers/vipManager");
const AchievementManager = require("../managers/achievementManager");
const SeasonManager = require("../managers/seasonManager");
const mmoRepo = require("../repositories/mmoRepository");
const logger = require("../utils/logger");

class WorldService {
  constructor() {
    this.mapManager = new MapManager();
    this.playerManager = new PlayerManager();
    this.entityManager = new EntityManager();
    this.chatManager = new ChatManager(config);
    this.tradeManager = new TradeManager();
    this.guildManager = new GuildManager();
    this.pvpManager = new PvpManager(this.mapManager);
    this.combatManager = new CombatManager({
      pvpManager: this.pvpManager,
      entityManager: this.entityManager
    });
    this.bossManager = new BossManager(this.entityManager);
    this.partyManager = new PartyManager();
    this.saveManager = new SaveManager();
    this.professionManager = new ProfessionManager();
    this.craftingManager = new CraftingManager({ professionManager: this.professionManager });
    this.petManager = new PetManager();
    this.mountManager = new MountManager();
    this.dungeonManager = new DungeonManager();
    this.rankManager = new RankManager();
    this.marketManager = new MarketManager();
    this.vipManager = new VipManager();
    this.achievementManager = new AchievementManager();
    this.seasonManager = new SeasonManager();
    this.eventManager = new EventManager({
      onBroadcast: (payload) => this.broadcastAll(payload),
      bossManager: this.bossManager
    });
    this.antiCheat = new AntiCheatManager();
    this.lastSaveTick = Date.now();
  }

  async bootstrapMmoSystems() {
    await this.petManager.bootstrapDefinitions();
    await this.mountManager.bootstrapDefinitions();
    await this.dungeonManager.bootstrapDefinitions();
    await this.achievementManager.bootstrapDefinitions();
    await this.seasonManager.bootstrapDefinitions();
    await this.rankManager.computeAll();
  }

  attachTransport(transport) {
    this.transport = transport;
  }

  status() {
    const mapCounts = {};
    for (const player of this.playerManager.all()) {
      mapCounts[player.map] = (mapCounts[player.map] || 0) + 1;
    }
    return {
      onlinePlayers: this.playerManager.all().length,
      maps: mapCounts,
      tickMs: config.worldTickMs,
      saveIntervalMs: config.saveIntervalMs
    };
  }

  addPlayer(socket, payload) {
    const exists = this.playerManager.get(payload.character.id);
    if (exists) {
      throw new Error("Login duplicado com mesmo personagem.");
    }
    const session = this.playerManager.addSession(socket, payload);
    this.transport.send(socket, {
      type: "world_entered",
      self: session,
      map: this.mapManager.get(session.map)
    });
    this.sendMapSnapshot(session);
    this.broadcastMapExcept(session.map, session.characterId, {
      type: "player_joined",
      player: this.snapshotPlayer(session)
    });
    return session;
  }

  async removePlayer(socket) {
    const session = this.playerManager.removeSession(socket);
    if (!session) return;
    this.tradeManager.cancelForCharacter(session.characterId);
    this.antiCheat.clear(session.characterId);
    await this.saveManager.savePlayerState(session);
    this.broadcastMap(session.map, {
      type: "player_left",
      characterId: session.characterId
    });
  }

  snapshotPlayer(p) {
    return {
      characterId: p.characterId,
      name: p.name,
      className: p.className,
      level: p.level,
      hp: p.hp,
      mana: p.mana,
      map: p.map,
      pos: p.pos,
      guildId: p.guildId
    };
  }

  playersNear(player, radius = Number.POSITIVE_INFINITY) {
    const players = this.playerManager.playersInMap(player.map);
    return players.filter((other) => {
      if (other.characterId === player.characterId) return false;
      if (!Number.isFinite(radius)) return true;
      const dx = other.pos.x - player.pos.x;
      const dy = other.pos.y - player.pos.y;
      return dx * dx + dy * dy <= radius * radius;
    });
  }

  sendMapSnapshot(player) {
    const players = this.playersNear(player).map((p) => this.snapshotPlayer(p));
    const bosses = this.entityManager.listBossesByMap(player.map);
    this.transport.send(player.socket, {
      type: "world_snapshot",
      players,
      bosses
    });
  }

  sendNearbySnapshot() {
    for (const player of this.playerManager.all()) {
      this.sendMapSnapshot(player);
    }
  }

  broadcastAll(payload) {
    for (const player of this.playerManager.all()) {
      this.transport.send(player.socket, payload);
    }
  }

  broadcastMap(mapId, payload) {
    for (const player of this.playerManager.playersInMap(mapId)) {
      this.transport.send(player.socket, payload);
    }
  }

  broadcastMapExcept(mapId, exceptCharacterId, payload) {
    for (const player of this.playerManager.playersInMap(mapId)) {
      if (player.characterId === exceptCharacterId) continue;
      this.transport.send(player.socket, payload);
    }
  }

  receiveMove(socket, msg) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const mapId = this.mapManager.exists(msg.map) ? msg.map : player.map;
    const pos = this.mapManager.clampPosition(mapId, msg.pos || {});
    this.playerManager.queueMove(player.characterId, mapId, pos);
  }

  async handleCharacterSave(socket, msg) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const state = msg.state && typeof msg.state === "object" ? msg.state : {};
    const mapId = this.mapManager.exists(state.map) ? state.map : player.map;
    player.level = this._safeInt(state.level, player.level, 1, 999);
    player.xp = this._safeInt(state.xp, player.xp, 0, 999999999);
    player.hp = this._safeInt(state.hp, player.hp, 0, 999999);
    player.mana = this._safeInt(state.mana, player.mana, 0, 999999);
    player.gold = this._safeInt(state.gold, player.gold, 0, 999999999);
    player.map = mapId;
    player.pos = this.mapManager.clampPosition(mapId, state.pos || player.pos);
    const skills = this._sanitizeSkills(state.skills);
    if (skills) {
      player.skills = skills;
    }
    await this.saveManager.savePlayerState(player);
    this.transport.send(socket, { type: "character_saved", ok: true });
  }

  _safeInt(value, fallback, min, max) {
    const parsed = Number.parseInt(value, 10);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(min, Math.min(max, parsed));
  }

  _sanitizeSkills(skills) {
    if (!skills || typeof skills !== "object") return null;
    const result = {};
    for (const key of ["fighting", "distance", "magic", "protection"]) {
      const item = skills[key] && typeof skills[key] === "object" ? skills[key] : {};
      result[key] = {
        level: this._safeInt(item.level, 10, 1, 999),
        xp: this._safeInt(item.xp, 0, 0, 999999999)
      };
    }
    return result;
  }

  processMoves(nowMs) {
    for (const [characterId, move] of this.playerManager.drainPendingMoves()) {
      const player = this.playerManager.get(characterId);
      if (!player) continue;
      const previousMap = player.map;
      const mapChanged = previousMap !== move.map;
      const anti = mapChanged ? { ok: true } : this.antiCheat.validateMove(characterId, move.pos, nowMs);
      if (!anti.ok) {
        this.transport.send(player.socket, {
          type: "anti_cheat_violation",
          reason: anti.reason
        });
        continue;
      }
      if (mapChanged) {
        this.antiCheat.clear(characterId);
        this.broadcastMapExcept(previousMap, player.characterId, {
          type: "player_left",
          characterId: player.characterId
        });
      }
      player.map = move.map;
      player.pos = move.pos;
      if (mapChanged) {
        this.antiCheat.validateMove(characterId, move.pos, nowMs);
      }
      if (mapChanged) {
        this.sendMapSnapshot(player);
        this.broadcastMapExcept(player.map, player.characterId, {
          type: "player_joined",
          player: this.snapshotPlayer(player)
        });
      }
    }
  }

  handleChat(socket, msg) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    if (!this.chatManager.canTalk(player.characterId)) {
      this.transport.send(socket, {
        type: "chat_error",
        text: "Anti-flood: aguarde alguns segundos."
      });
      return;
    }
    const channel = String(msg.channel || "global");
    const message = this.chatManager.buildMessage(channel, player.name, msg.text || "");
    if (channel === "local") {
      this.transport.send(socket, message);
      for (const near of this.playersNear(player, 420)) {
        this.transport.send(near.socket, message);
      }
      return;
    }
    if (channel === "guild" && player.guildId) {
      for (const p of this.playerManager.all()) {
        if (p.guildId === player.guildId) {
          this.transport.send(p.socket, message);
        }
      }
      return;
    }
    this.broadcastAll(message);
  }

  handlePvpAttack(socket, msg) {
    const attacker = this.playerManager.getBySocket(socket);
    if (!attacker) return;
    const defender = this.playerManager.get(Number(msg.targetCharacterId));
    if (!defender) return;
    const result = this.combatManager.attackPlayer(attacker, defender, {
      power: Number(msg.power || 1.0),
      baseAttack: Number(msg.baseAttack || 12)
    });
    this.transport.send(socket, { type: "pvp_attack_result", ...result, targetCharacterId: defender.characterId });
    if (result.ok) {
      this.transport.send(defender.socket, {
        type: "pvp_damage_taken",
        from: attacker.characterId,
        damage: result.damage,
        hp: defender.hp
      });
      this.broadcastMap(attacker.map, {
        type: "entity_hp_sync",
        characterId: defender.characterId,
        hp: defender.hp
      });
    }
  }

  handleBossAttack(socket, msg) {
    const attacker = this.playerManager.getBySocket(socket);
    if (!attacker) return;
    const result = this.combatManager.attackBoss(attacker, msg.bossId, {
      power: Number(msg.power || 1.0),
      baseAttack: Number(msg.baseAttack || 12)
    });
    this.transport.send(socket, { type: "boss_attack_result", ...result, bossId: msg.bossId });
  }

  async handleProfessions(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const data = await this.professionManager.snapshot(player.characterId);
    this.transport.send(socket, { type: "professions_state", professions: data });
  }

  async handleCraftList(socket) {
    this.transport.send(socket, { type: "crafting_recipes", recipes: this.craftingManager.listRecipes() });
  }

  async handleCraftAttempt(socket, msg) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const result = await this.craftingManager.craft(player.characterId, String(msg.recipeCode || ""));
    this.transport.send(socket, { type: "crafting_result", ...result });
  }

  async handlePetsState(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const pets = await this.petManager.list(player.characterId);
    this.transport.send(socket, { type: "pets_state", pets });
  }

  async handlePetEquip(socket, msg) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const pets = await this.petManager.equip(player.characterId, Number(msg.characterPetId));
    this.transport.send(socket, { type: "pets_state", pets });
  }

  async handleMountsState(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const mounts = await this.mountManager.list(player.characterId);
    this.transport.send(socket, { type: "mounts_state", mounts });
  }

  async handleMountEquip(socket, msg) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const mounts = await this.mountManager.equip(player.characterId, Number(msg.characterMountId), {
      inCombat: false,
      inDungeon: false
    });
    this.transport.send(socket, { type: "mounts_state", mounts });
  }

  async handleDungeonsState(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const list = await this.dungeonManager.list();
    this.transport.send(socket, { type: "dungeons_state", dungeons: list });
  }

  async handleDungeonStart(socket, msg) {
    const leader = this.playerManager.getBySocket(socket);
    if (!leader) return;
    const partyMembers = leader.partyId
      ? this.playerManager.all().filter((p) => p.partyId === leader.partyId)
      : [leader];
    const started = await this.dungeonManager.startRun({
      dungeonCode: String(msg.dungeonCode || ""),
      leader,
      members: partyMembers
    });
    for (const member of partyMembers) {
      this.transport.send(member.socket, { type: "dungeon_started", ...started });
    }
  }

  async handleRankRequest(socket, msg) {
    const key = String(msg.rankKey || "top_level");
    const payload = await this.rankManager.get(key);
    this.transport.send(socket, { type: "rank_state", rankKey: key, rows: payload });
  }

  async handleMarketList(socket, msg) {
    const filters = {
      category: msg.category ? String(msg.category) : undefined,
      rarity: msg.rarity ? String(msg.rarity) : undefined,
      itemId: msg.search ? String(msg.search) : undefined
    };
    const listings = await this.marketManager.list(filters);
    this.transport.send(socket, { type: "market_state", listings });
  }

  async handleMarketCreate(socket, msg) {
    const seller = this.playerManager.getBySocket(socket);
    if (!seller) return;
    const listing = await this.marketManager.createListing({
      sellerCharacterId: seller.characterId,
      itemId: String(msg.itemId || ""),
      quantity: Number(msg.quantity || 1),
      price: Number(msg.price || 0),
      rarity: String(msg.rarity || "common"),
      category: String(msg.category || "misc")
    });
    this.transport.send(socket, { type: "market_listing_created", listing });
  }

  async handleMarketBuy(socket, msg) {
    const buyer = this.playerManager.getBySocket(socket);
    if (!buyer) return;
    const result = await this.marketManager.buy(Number(msg.listingId), buyer.characterId);
    this.transport.send(socket, { type: "market_buy_result", ...result });
  }

  async handleVipStatus(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const vip = await this.vipManager.status(player.accountId);
    this.transport.send(socket, { type: "vip_state", vip });
  }

  async handleAchievementsState(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const achievements = await this.achievementManager.list(player.characterId);
    this.transport.send(socket, { type: "achievements_state", achievements });
  }

  async handleSeasonState(socket) {
    const player = this.playerManager.getBySocket(socket);
    if (!player) return;
    const season = await this.seasonManager.activeSeason();
    if (!season) {
      this.transport.send(socket, { type: "season_state", season: null });
      return;
    }
    const progress = await mmoRepo.getSeasonProgress(player.characterId, season.id);
    this.transport.send(socket, { type: "season_state", season, progress });
  }

  async tick() {
    const nowMs = Date.now();
    this.processMoves(nowMs);
    this.sendNearbySnapshot();
    this.eventManager.tick(nowMs);

    const deadBosses = this.bossManager.tryFinalizeDeadBoss();
    for (const boss of deadBosses) {
      this.broadcastMap(boss.map, {
        type: "boss_defeated",
        bossId: boss.id,
        name: boss.name,
        contribution: boss.contribution
      });
    }

    const expiredRuns = this.dungeonManager.tick();
    for (const runId of expiredRuns) {
      await this.dungeonManager.finishRun(runId, false);
    }

    await this.rankManager.computeIfNeeded();

    if (nowMs - this.lastSaveTick >= config.saveIntervalMs) {
      this.lastSaveTick = nowMs;
      await this.saveManager.saveAll(this.playerManager.all());
      logger.info("Auto-save executado.");
    }
  }
}

module.exports = WorldService;
