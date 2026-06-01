CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS accounts (
  id BIGSERIAL PRIMARY KEY,
  username VARCHAR(32) NOT NULL UNIQUE,
  email VARCHAR(120) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login TIMESTAMPTZ,
  banned BOOLEAN NOT NULL DEFAULT FALSE,
  vip BOOLEAN NOT NULL DEFAULT FALSE,
  premium_days INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS characters (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  name VARCHAR(32) NOT NULL UNIQUE,
  class VARCHAR(24) NOT NULL,
  level INT NOT NULL DEFAULT 1,
  xp BIGINT NOT NULL DEFAULT 0,
  hp INT NOT NULL DEFAULT 100,
  mana INT NOT NULL DEFAULT 50,
  gold BIGINT NOT NULL DEFAULT 0,
  map VARCHAR(64) NOT NULL DEFAULT 'city_eldoria',
  pos_x FLOAT8 NOT NULL DEFAULT 1080,
  pos_y FLOAT8 NOT NULL DEFAULT 760,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  item_id VARCHAR(80) NOT NULL,
  amount INT NOT NULL DEFAULT 1,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE(character_id, item_id)
);

CREATE TABLE IF NOT EXISTS equipment (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL UNIQUE REFERENCES characters(id) ON DELETE CASCADE,
  amulet VARCHAR(80),
  helmet VARCHAR(80),
  backpack VARCHAR(80),
  shield VARCHAR(80),
  armor VARCHAR(80),
  weapon VARCHAR(80),
  ring VARCHAR(80),
  pants VARCHAR(80),
  jewel VARCHAR(80),
  boots VARCHAR(80),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS skills (
  character_id BIGINT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
  fighting_level INT NOT NULL DEFAULT 10,
  fighting_xp BIGINT NOT NULL DEFAULT 0,
  distance_level INT NOT NULL DEFAULT 10,
  distance_xp BIGINT NOT NULL DEFAULT 0,
  magic_level INT NOT NULL DEFAULT 10,
  magic_xp BIGINT NOT NULL DEFAULT 0,
  protection_level INT NOT NULL DEFAULT 10,
  protection_xp BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS guilds (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(40) NOT NULL UNIQUE,
  owner_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE RESTRICT,
  level INT NOT NULL DEFAULT 1,
  motd TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS guild_members (
  guild_id BIGINT NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  role VARCHAR(16) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (guild_id, character_id)
);

CREATE TABLE IF NOT EXISTS quests (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  quest_id VARCHAR(64) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  progress JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(character_id, quest_id)
);

CREATE TABLE IF NOT EXISTS friends (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  friend_character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(character_id, friend_character_id)
);

CREATE TABLE IF NOT EXISTS mail (
  id BIGSERIAL PRIMARY KEY,
  sender_character_id BIGINT REFERENCES characters(id) ON DELETE SET NULL,
  target_character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  subject VARCHAR(80) NOT NULL,
  body TEXT NOT NULL,
  attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market (
  id BIGSERIAL PRIMARY KEY,
  seller_character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  item_id VARCHAR(80) NOT NULL,
  amount INT NOT NULL,
  unit_price BIGINT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trade_logs (
  id BIGSERIAL PRIMARY KEY,
  actor_a BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  actor_b BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS parties (
  id BIGSERIAL PRIMARY KEY,
  leader_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS party_members (
  party_id BIGINT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  role VARCHAR(16) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (party_id, character_id)
);

CREATE TABLE IF NOT EXISTS online_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  character_id BIGINT REFERENCES characters(id) ON DELETE SET NULL,
  token_jti UUID NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  ip VARCHAR(80),
  user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_characters_account_id ON characters(account_id);
CREATE INDEX IF NOT EXISTS idx_inventory_character_id ON inventory(character_id);
CREATE INDEX IF NOT EXISTS idx_trade_logs_created_at ON trade_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mail_target_character_id ON mail(target_character_id);

ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS vip_days INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vip_active BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS vip_expire_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS professions (
  character_id BIGINT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
  mining_level INT NOT NULL DEFAULT 1,
  mining_xp BIGINT NOT NULL DEFAULT 0,
  woodcutting_level INT NOT NULL DEFAULT 1,
  woodcutting_xp BIGINT NOT NULL DEFAULT 0,
  herbalism_level INT NOT NULL DEFAULT 1,
  herbalism_xp BIGINT NOT NULL DEFAULT 0,
  blacksmithing_level INT NOT NULL DEFAULT 1,
  blacksmithing_xp BIGINT NOT NULL DEFAULT 0,
  alchemy_level INT NOT NULL DEFAULT 1,
  alchemy_xp BIGINT NOT NULL DEFAULT 0,
  cooking_level INT NOT NULL DEFAULT 1,
  cooking_xp BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS crafting_recipes (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  category VARCHAR(24) NOT NULL,
  profession VARCHAR(24) NOT NULL,
  profession_level_required INT NOT NULL DEFAULT 1,
  materials JSONB NOT NULL DEFAULT '[]'::jsonb,
  gold_cost BIGINT NOT NULL DEFAULT 0,
  result_item_id VARCHAR(80) NOT NULL,
  result_amount INT NOT NULL DEFAULT 1,
  success_chance NUMERIC(5,2) NOT NULL DEFAULT 100.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pets (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(80) NOT NULL,
  rarity VARCHAR(16) NOT NULL DEFAULT 'common',
  base_bonus JSONB NOT NULL DEFAULT '{}'::jsonb,
  sprite VARCHAR(180) NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS character_pets (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  pet_id BIGINT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  level INT NOT NULL DEFAULT 1,
  xp BIGINT NOT NULL DEFAULT 0,
  equipped BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(character_id, pet_id)
);

CREATE TABLE IF NOT EXISTS mounts (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(80) NOT NULL,
  rarity VARCHAR(16) NOT NULL DEFAULT 'common',
  speed_bonus NUMERIC(5,2) NOT NULL DEFAULT 0,
  extra_bonus JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS character_mounts (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  mount_id BIGINT NOT NULL REFERENCES mounts(id) ON DELETE CASCADE,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  equipped BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(character_id, mount_id)
);

CREATE TABLE IF NOT EXISTS dungeons (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  min_level INT NOT NULL DEFAULT 1,
  max_party_size INT NOT NULL DEFAULT 1,
  time_limit_seconds INT NOT NULL DEFAULT 1200,
  reward_cooldown_hours INT NOT NULL DEFAULT 24
);

CREATE TABLE IF NOT EXISTS dungeon_runs (
  id BIGSERIAL PRIMARY KEY,
  dungeon_id BIGINT NOT NULL REFERENCES dungeons(id) ON DELETE CASCADE,
  leader_character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  members JSONB NOT NULL DEFAULT '[]'::jsonb,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  reward_claimed BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS rank_cache (
  id BIGSERIAL PRIMARY KEY,
  rank_key VARCHAR(80) NOT NULL UNIQUE,
  payload JSONB NOT NULL DEFAULT '[]'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS market_listings (
  id BIGSERIAL PRIMARY KEY,
  seller_character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  item_id VARCHAR(80) NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  price BIGINT NOT NULL,
  rarity VARCHAR(16) NOT NULL DEFAULT 'common',
  category VARCHAR(24) NOT NULL DEFAULT 'misc',
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sold_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS achievements (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  description TEXT NOT NULL,
  category VARCHAR(24) NOT NULL,
  objective INT NOT NULL DEFAULT 1,
  reward JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS character_achievements (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  achievement_id BIGINT NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  progress INT NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  rewarded BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  UNIQUE(character_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS seasons (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  active BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS season_progress (
  id BIGSERIAL PRIMARY KEY,
  character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  season_id BIGINT NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
  level INT NOT NULL DEFAULT 1,
  xp BIGINT NOT NULL DEFAULT 0,
  premium_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(character_id, season_id)
);

CREATE TABLE IF NOT EXISTS premium_purchases (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  purchase_type VARCHAR(24) NOT NULL,
  reference_code VARCHAR(80) NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_market_listings_status ON market_listings(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rank_cache_key ON rank_cache(rank_key);
CREATE INDEX IF NOT EXISTS idx_character_achievements_character ON character_achievements(character_id);
