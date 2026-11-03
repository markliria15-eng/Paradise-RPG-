"""Simulacao aproximada da luta contra o Rei Javali (so para calibrar)."""
import random

import sys
BOSS = dict(vida=int(sys.argv[1]), ataque=int(sys.argv[2]), defesa=int(sys.argv[3]))
INTERVAL, ENRAGED_INTERVAL, ENRAGE = 1.6, 1.15, 0.35
CHARGE_CYCLE = 4.0 + 0.85 + 0.5 + 1.2


def dmg(atk, df, mult=1.0):
    return max(1, round(atk * mult + random.randint(-2, 3) - df))


def fight(cls, level, gear, melee_hit_rate, charge_hit_rate, potions=3, seed=None):
    rnd = random.Random(seed)
    random.seed(rnd.random())
    base = {"guerreiro": (150, 40, 12, 10, 1.0), "arqueiro": (110, 80, 10, 6, 1.3), "maga": (90, 150, 8, 4, 0.8)}[cls]
    hp = base[0] + (level - 1) * 10 + gear["vida"]
    mana = base[1] + (level - 1) * 5
    atk = base[2] + (level - 1) + gear["ataque"]
    df = base[3] + (level - 1) // 2 + gear["defesa"]
    aps = base[4]
    hp_max = hp
    boss = BOSS["vida"]
    t, dt = 0.0, 0.05
    next_player, next_boss, next_charge = 0.0, 1.0, 3.0
    stun_until, hits_taken = 0.0, 0
    cds = {}
    skills = {
        "guerreiro": [("soul", 14, 34, 2.8), ("area", 10, 22, 1.25)],
        "arqueiro": [("stun", 10, 24, 1.45), ("rain", 12, 28, 1.15 * 3)],
        "maga": [("meteor", 13, 55, 2.7), ("fireball", 5, 22, 1.35 + 0.6)],
    }[cls]
    while t < 400:
        t += dt
        mana = min(base[1] + (level - 1) * 5, mana + 1.2 * dt)
        enraged = boss <= BOSS["vida"] * ENRAGE
        if t >= stun_until and t >= next_player:
            mult = 1.0
            for name, cd, cost, power in skills:
                if cds.get(name, 0) <= t and mana >= cost:
                    cds[name] = t + cd
                    mana -= cost
                    mult = power
                    break
            boss -= dmg(atk, BOSS["defesa"], mult)
            next_player = t + 1.0 / aps
            if boss <= 0:
                return True, t, hp
        if t >= next_boss:
            next_boss = t + (ENRAGED_INTERVAL if enraged else INTERVAL)
            if rnd.random() < melee_hit_rate or t < stun_until:
                d = dmg(BOSS["ataque"], df)
                hits_taken += 1
                if cls == "guerreiro" and hits_taken % 5 == 0:
                    d = round(d * 0.7)
                hp -= d
        if t >= next_charge:
            next_charge = t + CHARGE_CYCLE * (0.65 if enraged else 1.0)
            if rnd.random() < charge_hit_rate:
                hp -= dmg(BOSS["ataque"], df, 2.2)
                stun_until = t + 3.0
        if hp < hp_max * 0.35 and potions > 0:
            hp = min(hp_max, hp + 50)
            potions -= 1
        if hp <= 0:
            return False, t, boss
    return False, t, boss


GEAR = {
    "sem": dict(vida=0, ataque=5, defesa=0),
    "couro": dict(vida=30, ataque=5, defesa=8),
    "ferro": dict(vida=50, ataque=10, defesa=14),
}
for cls, melee, charge in (("guerreiro", 0.8, 0.45), ("arqueiro", 0.25, 0.35), ("maga", 0.25, 0.35)):
    for level in (5, 8, 10, 12):
        for gname in ("couro",):
            res = [fight(cls, level, GEAR[gname], melee, charge, seed=i) for i in range(300)]
            wins = [r for r in res if r[0]]
            avg_t = sum(r[1] for r in wins) / len(wins) if wins else 0
            print(f"{cls:9s} lvl {level:2d} {gname:5s}: vitoria {len(wins) / len(res):5.0%}  tempo medio {avg_t:5.0f}s")
