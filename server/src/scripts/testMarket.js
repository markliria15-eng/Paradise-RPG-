// Teste do mercado entre jogadores sem banco: troca o repositorio por um falso em memoria.
// uso: node server/src/scripts/testMarket.js
const path = require("path");
const assert = require("assert");

const repoPath = path.resolve(__dirname, "../repositories/mmoRepository.js");
const db = { listings: [], payouts: [], gold: { 1: 1000, 2: 50000 }, nextId: 1 };
require.cache[repoPath] = {
  id: repoPath, filename: repoPath, loaded: true,
  exports: {
    listMarket: async () => db.listings.filter((l) => l.status === "active"),
    createListing: async (l) => { const row = { id: db.nextId++, seller_character_id: l.sellerCharacterId, item_id: l.itemId, quantity: l.quantity, price: l.price, status: "active" }; db.listings.push(row); return row; },
    findListingById: async (id) => db.listings.find((l) => l.id === id) || null,
    closeListing: async (id, status, only) => { const l = db.listings.find((x) => x.id === id); if (!l || (only && l.status !== only)) return null; l.status = status; l.sold_at = Date.now(); return l; },
    reopenListing: async (id) => { db.listings.find((x) => x.id === id).status = "active"; },
    recentUnitPrices: async (itemId) => db.listings.filter((l) => l.item_id === itemId && l.status === "sold").map((l) => l.price / l.quantity),
    removeInventoryItem: async () => false,
    removeGold: async (id, amount) => { if (db.gold[id] < amount) return null; db.gold[id] -= amount; return { id }; },
    createPayout: async (seller, listingId, amount) => db.payouts.push({ seller, listingId, amount, collected: false }),
    sumPendingPayouts: async (id) => { const p = db.payouts.filter((x) => x.seller === id && !x.collected); return { total: p.reduce((s, x) => s + x.amount, 0), sales: p.length }; },
    collectPayouts: async (id) => { let t = 0; for (const p of db.payouts) if (p.seller === id && !p.collected) { p.collected = true; t += p.amount; } return t; },
  },
};

const MarketManager = require("../managers/marketManager");

(async () => {
  const m = new MarketManager();
  const base = await m.suggestedPrice("Espada de Mithril");
  assert.strictEqual(base.source, "valor_base");
  assert(base.suggested > 1000, "espada de mithril vale bem");
  const enc = await m.suggestedPrice("Espada de Mithril +3");
  assert(enc.suggested > base.suggested * 2, "encantada +3 vale mais");
  await assert.rejects(() => m.createListing({ sellerCharacterId: 1, itemId: "Item Que Nao Existe", quantity: 1, price: 10 }));
  // 3 vendas de pocao a 20/unidade -> recomendado vira 20
  for (let i = 0; i < 3; i++) {
    const l = await m.createListing({ sellerCharacterId: 1, itemId: "Pocao pequena de vida", quantity: 2, price: 40 });
    await m.buy(l.id, 2);
  }
  const pocao = await m.suggestedPrice("Pocao pequena de vida");
  assert.strictEqual(pocao.source, "mercado");
  assert.strictEqual(pocao.suggested, 20);
  // vendedor coleta (5% de taxa): 3 x 38
  const pend = await m.pendingPayouts(1);
  assert.strictEqual(pend.total, 114);
  assert.strictEqual((await m.collectPayouts(1)).amount, 114);
  assert.strictEqual((await m.pendingPayouts(1)).total, 0);
  // nao compra o proprio, nem sem ouro; cancelar devolve
  const caro = await m.createListing({ sellerCharacterId: 2, itemId: "Espada de Mithril", quantity: 1, price: 999999 });
  await assert.rejects(() => m.buy(caro.id, 2));
  await assert.rejects(() => m.buy(caro.id, 1));
  assert.strictEqual(db.listings.find((l) => l.id === caro.id).status, "active");
  const c = await m.cancelListing(caro.id, 2);
  assert.strictEqual(c.itemId, "Espada de Mithril");
  console.log("mercado OK");
})().catch((e) => { console.error(e); process.exit(1); });
