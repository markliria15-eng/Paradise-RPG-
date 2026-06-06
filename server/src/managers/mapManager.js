const fs = require("fs");
const path = require("path");

class MapManager {
  constructor() {
    this.maps = {
      city_eldoria: { pvp: false, width: 2200, height: 1400, safe: true },
      forest_boars: { pvp: true, width: 2200, height: 1400, safe: false },
      arcane_ruins: { pvp: true, width: 2200, height: 1400, safe: false },
      bat_cave: { pvp: true, width: 2200, height: 1400, safe: false },
      city_valdoria: { pvp: false, width: 2200, height: 1400, safe: true },
      highland_pass: { pvp: true, width: 2200, height: 1400, safe: false },
      crystal_mines: { pvp: true, width: 2200, height: 1400, safe: false },
      ember_fortress: { pvp: true, width: 2200, height: 1400, safe: false }
    };
    this.loadMapsFromData();
  }

  loadMapsFromData() {
    const mapsPath = path.resolve(__dirname, "../../../data/maps.json");
    if (!fs.existsSync(mapsPath)) return;
    try {
      const data = JSON.parse(fs.readFileSync(mapsPath, "utf8"));
      for (const [mapId, mapData] of Object.entries(data)) {
        const size = Array.isArray(mapData.size) ? mapData.size : [2200, 1400];
        const width = Number(size[0]) || 2200;
        const height = Number(size[1]) || 1400;
        const safe = Boolean(mapData.safe);
        this.maps[mapId] = {
          pvp: !safe,
          width,
          height,
          safe
        };
      }
    } catch (error) {
      // Keep fallback maps if the shared data file is not readable.
    }
  }

  exists(mapId) {
    return !!this.maps[mapId];
  }

  get(mapId) {
    return this.maps[mapId] || this.maps.city_eldoria;
  }

  isPvpEnabled(mapId) {
    return this.get(mapId).pvp;
  }

  clampPosition(mapId, pos) {
    const map = this.get(mapId);
    return {
      x: Math.max(0, Math.min(map.width, Number(pos.x) || 0)),
      y: Math.max(0, Math.min(map.height, Number(pos.y) || 0))
    };
  }
}

module.exports = MapManager;
