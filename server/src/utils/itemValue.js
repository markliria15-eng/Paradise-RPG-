// Valor de mercado dos itens (mesma conta do cliente: scripts/valor_itens.gd, dados em data/mercado.json).
// Usado no preco recomendado do mercado entre jogadores quando ainda nao ha vendas suficientes.
const { loadProjectJson } = require("./jsonLoader");

let cache = null;

function data() {
  if (!cache) {
    cache = { items: loadProjectJson("data/items.json"), market: loadProjectJson("data/mercado.json") };
  }
  return cache;
}

function enchantLevel(itemId) {
  const m = /^(.*) \+(\d+)$/.exec(String(itemId));
  return m ? { base: m[1], level: Number(m[2]) } : { base: String(itemId), level: 0 };
}

function baseValue(itemId) {
  const { items, market } = data();
  const { base, level } = enchantLevel(itemId);
  const info = items[base];
  if (!info) return 0;
  let value;
  if (Number(info.price) > 0) {
    value = Number(info.price);
  } else if (info.type === "equipment") {
    value = Number(market.valor_raridade[info.rarity || "common"] || 60) * Number(market.multiplicador_slot[info.slot] || 1);
  } else {
    value = Number((market.valor_material || {})[base] || market.material_padrao || 12);
  }
  value *= 1 + Number(market.encanto_por_nivel || 0.6) * level;
  return Math.max(1, Math.round(value));
}

function itemExists(itemId) {
  return Boolean(data().items[enchantLevel(itemId).base]);
}

function marketRules() {
  return data().market;
}

function median(values) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

module.exports = { baseValue, itemExists, marketRules, median, enchantLevel };
