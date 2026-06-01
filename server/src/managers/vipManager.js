const mmoRepo = require("../repositories/mmoRepository");

class VipManager {
  async grantDays(accountId, days) {
    if (days <= 0) throw new Error("Dias VIP invalidos.");
    await mmoRepo.setVip(accountId, days);
    return mmoRepo.getAccountVip(accountId);
  }

  async status(accountId) {
    return mmoRepo.getAccountVip(accountId);
  }

  xpBonusMultiplier(vipStatus) {
    return vipStatus?.vip_active ? 1.10 : 1.0;
  }

  professionXpBonusMultiplier(vipStatus) {
    return vipStatus?.vip_active ? 1.10 : 1.0;
  }
}

module.exports = VipManager;

