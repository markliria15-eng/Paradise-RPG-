const WebSocket = require("ws");
const authService = require("../services/authService");
const characterRepo = require("../repositories/characterRepository");
const logger = require("../utils/logger");

function safeJson(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}

class WsGateway {
  constructor({ port, worldService }) {
    this.wss = new WebSocket.Server({ port });
    this.world = worldService;
    this.world.attachTransport(this);
  }

  start() {
    this.wss.on("connection", (socket) => {
      socket.isAlive = true;
      socket.on("pong", () => {
        socket.isAlive = true;
      });

      socket.on("message", async (raw) => {
        const msg = safeJson(String(raw));
        if (!msg || typeof msg.type !== "string") {
          this.send(socket, { type: "error", message: "Pacote invalido." });
          return;
        }
        try {
          await this._handleMessage(socket, msg);
        } catch (err) {
          logger.warn("Falha ao processar pacote websocket", err.message);
          this.send(socket, { type: "error", message: err.message });
        }
      });

      socket.on("close", async () => {
        await this.world.removePlayer(socket);
      });
    });

    setInterval(() => {
      for (const socket of this.wss.clients) {
        if (socket.isAlive === false) {
          socket.terminate();
          continue;
        }
        socket.isAlive = false;
        socket.ping();
      }
    }, 10000);
  }

  send(socket, payload) {
    if (socket.readyState !== WebSocket.OPEN) return;
    socket.send(JSON.stringify(payload));
  }

  async _handleMessage(socket, msg) {
    switch (msg.type) {
      case "auth":
        return this._auth(socket, msg);
      case "move":
        return this.world.receiveMove(socket, msg);
      case "chat":
        return this.world.handleChat(socket, msg);
      case "pvp_attack":
        return this.world.handlePvpAttack(socket, msg);
      case "boss_attack":
        return this.world.handleBossAttack(socket, msg);
      case "trade_request":
        return this._tradeRequest(socket, msg);
      case "trade_accept":
        return this._tradeAccept(socket, msg);
      case "trade_offer":
        return this._tradeOffer(socket, msg);
      case "trade_confirm":
        return this._tradeConfirm(socket);
      case "guild_create":
        return this._guildCreate(socket, msg);
      case "guild_invite":
        return this._guildInvite(socket, msg);
      case "guild_accept_invite":
        return this._guildAcceptInvite(socket);
      case "party_invite":
        return this._partyInvite(socket, msg);
      case "party_accept":
        return this._partyAccept(socket);
      case "professions_get":
        return this.world.handleProfessions(socket);
      case "crafting_list":
        return this.world.handleCraftList(socket);
      case "crafting_craft":
        return this.world.handleCraftAttempt(socket, msg);
      case "pets_get":
        return this.world.handlePetsState(socket);
      case "pets_equip":
        return this.world.handlePetEquip(socket, msg);
      case "mounts_get":
        return this.world.handleMountsState(socket);
      case "mounts_equip":
        return this.world.handleMountEquip(socket, msg);
      case "dungeons_get":
        return this.world.handleDungeonsState(socket);
      case "dungeon_start":
        return this.world.handleDungeonStart(socket, msg);
      case "rank_get":
        return this.world.handleRankRequest(socket, msg);
      case "market_get":
        return this.world.handleMarketList(socket, msg);
      case "market_list_item":
        return this.world.handleMarketCreate(socket, msg);
      case "market_buy":
        return this.world.handleMarketBuy(socket, msg);
      case "vip_get":
        return this.world.handleVipStatus(socket);
      case "achievements_get":
        return this.world.handleAchievementsState(socket);
      case "season_get":
        return this.world.handleSeasonState(socket);
      default:
        this.send(socket, { type: "error", message: "Tipo de pacote nao suportado." });
    }
  }

  async _auth(socket, msg) {
    const claims = authService.verifyToken(msg.token);
    const characterId = Number(msg.characterId);
    const character = await characterRepo.findById(characterId);
    if (!character) throw new Error("Personagem nao encontrado.");
    if (String(character.account_id) !== String(claims.sub)) {
      throw new Error("Token nao corresponde ao personagem.");
    }
    this.world.addPlayer(socket, {
      accountId: Number(claims.sub),
      character
    });
    this.send(socket, { type: "auth_ok", characterId });
  }

  _tradeRequest(socket, msg) {
    const from = this.world.playerManager.getBySocket(socket);
    const to = this.world.playerManager.get(Number(msg.targetCharacterId));
    if (!from || !to) return;
    this.world.tradeManager.request(from, to);
    this.send(to.socket, {
      type: "trade_invite",
      fromCharacterId: from.characterId,
      fromName: from.name
    });
  }

  _tradeAccept(socket, msg) {
    const to = this.world.playerManager.getBySocket(socket);
    const from = this.world.playerManager.get(Number(msg.fromCharacterId));
    if (!to || !from) return;
    if (!this.world.tradeManager.hasRequest(from.characterId, to.characterId)) return;
    const trade = this.world.tradeManager.openTrade(from, to);
    this.send(from.socket, { type: "trade_opened", trade });
    this.send(to.socket, { type: "trade_opened", trade });
  }

  _tradeOffer(socket, msg) {
    const me = this.world.playerManager.getBySocket(socket);
    if (!me) return;
    const trade = this.world.tradeManager.updateOffer(me.characterId, msg.items || []);
    if (!trade) return;
    const otherId = trade.a === me.characterId ? trade.b : trade.a;
    const other = this.world.playerManager.get(otherId);
    if (other) this.send(other.socket, { type: "trade_offer_update", trade });
  }

  async _tradeConfirm(socket) {
    const me = this.world.playerManager.getBySocket(socket);
    if (!me) return;
    const status = this.world.tradeManager.confirm(me.characterId);
    if (!status.trade) return;
    const otherId = status.trade.a === me.characterId ? status.trade.b : status.trade.a;
    const other = this.world.playerManager.get(otherId);
    if (other) this.send(other.socket, { type: "trade_confirm_update", trade: status.trade });
    if (status.done) {
      await this.world.tradeManager.finalize(status.trade);
      this.send(me.socket, { type: "trade_done", tradeId: status.trade.id });
      if (other) this.send(other.socket, { type: "trade_done", tradeId: status.trade.id });
    }
  }

  async _guildCreate(socket, msg) {
    const owner = this.world.playerManager.getBySocket(socket);
    if (!owner) return;
    const guild = await this.world.guildManager.createGuild(owner, String(msg.name || ""));
    this.send(socket, { type: "guild_created", guild });
  }

  _guildInvite(socket, msg) {
    const inviter = this.world.playerManager.getBySocket(socket);
    const target = this.world.playerManager.get(Number(msg.targetCharacterId));
    if (!inviter || !target || !inviter.guildId) return;
    this.world.guildManager.invite(inviter.characterId, target.characterId);
    this.send(target.socket, {
      type: "guild_invite",
      fromCharacterId: inviter.characterId,
      fromName: inviter.name,
      guildId: inviter.guildId
    });
  }

  async _guildAcceptInvite(socket) {
    const target = this.world.playerManager.getBySocket(socket);
    if (!target) return;
    const invite = this.world.guildManager.popInvite(target.characterId);
    if (!invite) return;
    const inviter = this.world.playerManager.get(invite.inviterId);
    if (!inviter || !inviter.guildId) return;
    await this.world.guildManager.joinByInvite(target, inviter.guildId);
    const info = await this.world.guildManager.guildInfoByCharacter(target.characterId);
    this.send(target.socket, { type: "guild_joined", info });
  }

  _partyInvite(socket, msg) {
    const leader = this.world.playerManager.getBySocket(socket);
    const target = this.world.playerManager.get(Number(msg.targetCharacterId));
    if (!leader || !target) return;
    this.world.partyManager.invite(leader.characterId, target.characterId);
    this.send(target.socket, {
      type: "party_invite",
      fromCharacterId: leader.characterId,
      fromName: leader.name
    });
  }

  _partyAccept(socket) {
    const target = this.world.playerManager.getBySocket(socket);
    if (!target) return;
    const party = this.world.partyManager.accept(target.characterId);
    if (!party) return;
    for (const memberId of party.members) {
      const member = this.world.playerManager.get(memberId);
      if (member) {
        member.partyId = party.id;
        this.send(member.socket, { type: "party_update", party });
      }
    }
  }
}

module.exports = WsGateway;
