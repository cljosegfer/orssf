# Pre-Renewal Stat Reference

Every primary and derived stat's in-game effect, sourced directly from the compiled formulas in this repository's `src/map/` tree — not from the renewal branch, and not from wiki lore.

**Build confirmed pre-renewal:** `src/config/renewal.hpp` defines `PRERE`, which disables `RENEWAL`, `RENEWAL_ASPD`, `RENEWAL_CAST`, `RENEWAL_STAT` and related renewal-only code paths. Every formula below is from the `#ifndef RENEWAL` / `#else` branch — the code path actually compiled into this server.

---

## Quick reference

| Stat | Primary effect | Also affects |
|---|---|---|
| **STR** | Melee base ATK, +1 per point (plus a small quadratic bonus every 10 points) | Carry weight (+300 per point); is the ranged-weapon "DEX-equivalent" term |
| **AGI** | Attack speed (ASPD) and base FLEE, +1 per point | Reduces stagger/hitlock duration (DMOTION) |
| **VIT** | Max HP (+1% per point) and soft DEF (DEF2) | HP regen, magic soft-DEF (MDEF2), status-ailment resistance |
| **INT** | MATK and Max SP (+1% per point) | SP regen, soft magic-DEF (MDEF2), Sleep resistance |
| **DEX** | Base HIT and variable cast-time reduction | Ranged base ATK, small ASPD bonus, minimum damage roll |
| **LUK** | Critical rate and Perfect Dodge (FLEE2) | Small ATK bonus, drop rate, most status-ailment resistance |

---

## Primary stats

### STR — Strength

```
baseATK += STR + (STR/10)² + DEX/5 + LUK/5     // melee weapons
```

For bow, instrument, whip, and gun-type weapons, STR and DEX swap roles:

```
baseATK += DEX + (DEX/10)² + STR/5 + LUK/5     // ranged weapons
```

This base ATK is added to the weapon's own ATK to form total ATK.

Carry weight: `max_weight = job_base_weight + STR × 300`.

**Source:** `status.cpp:2467-2474` (`status_base_atk`), `status.cpp:3652` (`status_calc_weight`)

### AGI — Agility

```
amotion -= amotion × (4×AGI + DEX) / 1000
```

Every point of AGI cuts 0.4% off the weapon/job's base attack delay; DEX contributes 0.1% per point. This is a percentage reduction off the base delay, then clamped to the server's ASPD cap. STR has no effect on attack speed.

```
flee = level + AGI
```

Base FLEE is a flat 1-for-1 with AGI — no LUK term in pre-renewal, unlike renewal's formula.

AGI also shortens DMOTION (the stagger window after being hit): `dmotion = clamp(800 − AGI×4, 400, 800)`.

**Source:** `status.cpp:2402` (`status_base_amotion_pc`), `status.cpp:2699` (`status_calc_misc`), `status.cpp:4631-4632`

### VIT — Vitality

```
maxHP = job_base_hp[level] × (1 + VIT × 0.01)
```

Each point of VIT is a flat +1% to max HP, before the ×1.25 (2nd class/trans) or ×3 (Taekwon ranker) job multiplier and any flat/rate item bonuses. This formula is identical in renewal — VIT's HP scaling isn't a pre-re-specific number.

```
def2 = VIT     // soft DEF, base
```

VIT also drives the flat damage subtraction applied after percentage DEF reduction. For a player target:

```
vit_def = 0.3×DEF2 + rnd(0, max(0, DEF2²/150 − 0.3×DEF2 − 1)) + 0.5×DEF2
```

...subtracted directly from incoming melee damage.

HP regen: `regen.hp = VIT/5 + max(1, maxHP/200)` per tick.

**Source:** `status.cpp:3500-3541` (`status_calc_maxhp_pc`), `status.cpp:2703`, `battle.cpp:7095-7099` (`battle_calc_defense_reduction`), `status.cpp:5265`

### INT — Intelligence

```
matk_min = INT + (INT/7)²
matk_max = INT + (INT/5)²
```

This is the entire magic-attack formula in pre-renewal — a flat term plus a quadratic term that accelerates past roughly INT 70–90. There is no separate MATK-from-weapon component the way renewal has.

```
maxSP = job_base_sp[level] × (1 + INT × 0.01)
```

Same +1%-per-point structure as VIT→HP. SP regen: `regen.sp = 1 + INT/6 + maxSP/100`, with an extra `(INT−120)/2 + 4` once INT reaches 120.

> INT does **not** reduce cast time in pre-renewal — only DEX does (see Casting, below). This is the biggest practical divergence from renewal for casters.

**Source:** `status.cpp:2504-2505` (`status_base_matk_min/max`), `status.cpp:3551-3593`, `status.cpp:5274-5276`

### DEX — Dexterity

```
hit = level + DEX
```

Flat 1-for-1, no LUK term (unlike renewal). DEX also feeds ASPD (+0.1%/point, see AGI) and contributes `DEX/5` to melee base ATK — or is the dominant ATK stat for bow/gun-type weapons, swapping with STR.

```
castTime *= max(0, 150 − DEX) / 150
```

Variable cast time scales straight down to zero as DEX approaches 150 (the default `castrate_dex_scale`, `conf/battle/skill.conf`); at DEX ≥ 150, all variable-cast skills become instant. There is no fixed/variable cast split in pre-re the way renewal has — this reduction applies to the skill's entire cast time.

DEX also sets the floor of the melee damage roll: `atkmin = DEX × (80 + weapon_level×20) / 100`.

**Source:** `status.cpp:2695` (`status_calc_misc`), `status.cpp:2402`, `skill.cpp:20224-20239` (`skill_castfix`), `battle.cpp:2537-2540`

### LUK — Luck

```
cri   = 10 + LUK × 10/3     // scale: 10 = 1%
flee2 = LUK + 10            // perfect dodge, same scale
```

Roughly 3 LUK per 1% crit chance; roughly 10 LUK per 1% perfect-dodge chance (which bypasses the hit roll entirely). LUK also adds `LUK/5` to base ATK, and reduces the attacker's effective crit chance against you by `2×LUK` (players) or `3×LUK` (monsters attacking you).

LUK is **not** part of base HIT or base FLEE in pre-renewal (both are renewal-only additions), so its combat role is narrower than in renewal — almost entirely crit, perfect dodge, and status resistance.

Also feeds steal success (`DEX/2 + LUK/2 + …`) and, if enabled in `battle_config`, item/zeny drop-rate bonuses on the killing blow.

**Source:** `status.cpp:2718, 2726` (`status_calc_misc`), `battle.cpp:3052` (`is_attack_critical`), `pc.cpp:6879`, `mob.cpp:2831-2834`

---

## ATK / MATK

### ATK

Total ATK = **base ATK** (the STR/DEX/LUK formula above) + **weapon ATK** (the equipped weapon's DB value, plus refine bonus). Non-crit damage rolls `rnd(atkmin, atkmax) + baseATK`, where `atkmin` is the DEX floor described above and `atkmax` is the weapon's max ATK.

> Pre-renewal crits skip the roll entirely and use the weapon's max ATK directly — there's no flat +40% crit multiplier the way renewal has; the "bonus" is guaranteeing the top of the damage range.

**Source:** `status.cpp:2416-2488, 2731`; `battle.cpp:2507-2624`

### MATK

Magic damage uses `matk_min`/`matk_max` (the INT formula above) directly as the attack roll — there's no separate weapon-MATK term for players in pre-renewal the way renewal splits it. MDEF is then applied to that roll (see below).

**Source:** `status.cpp:2504-2505, 2687-2692`; `battle.cpp:9593-9602`

---

## DEF / MDEF

### DEF (hard) & DEF2 (soft)

Hard DEF is the sum of equipped gear's DEF values plus refine bonus, capped at 100 for the damage-reduction step. Soft DEF2 is `VIT` (see above) — VIT-derived, not equipment-derived.

```
damage = damage × (100 − DEF) / 100
damage = damage − vit_def
```

Percentage reduction from hard DEF, then a flat subtraction from soft DEF2 (the VIT formula above). This two-stage model is specific to pre-renewal; renewal uses a single `(4000+DEF)/(4000+DEF×10)` curve instead.

> Steel Body (`SC_STEELBODY`) overrides DEF to a flat 90 in pre-renewal only — renewal removed this effect.

**Source:** `battle.cpp:7095-7169` (`battle_calc_defense_reduction`), `status.cpp:4575-4580`, `status.cpp:7758-7761`

### MDEF (hard) & MDEF2 (soft)

Hard MDEF sums from gear, same 100 cap. Soft MDEF2 is `INT + VIT/2`.

```
damage = damage × (100 − MDEF) / 100
damage = damage − MDEF2
```

Same two-stage shape as physical DEF. Steel Body also grants a flat 90 MDEF, pre-renewal only.

**Source:** `battle.cpp:9594-9602`, `status.cpp:2707`, `status.cpp:4592-4597`, `status.cpp:7928-7931`

---

## Hit / Flee / Critical

### Hit chance

```
hitrate = 80 + HIT − target.FLEE     // clamped 5–100%
```

Pre-renewal starts the roll at an 80% baseline (renewal starts at 0 and computes the whole thing from the HIT/FLEE gap), then a straight `rnd()%100 < hitrate` check decides the hit — unless perfect dodge triggers first.

**Source:** `battle.cpp:3244-3387` (`is_attack_hitting`)

### Perfect dodge

Checked before the hit roll: `rnd()%1000 < FLEE2` bypasses the attack entirely, independent of the attacker's HIT.

**Source:** `battle.cpp:7854`

### Critical trigger

Attacker's effective crit stat is reduced by the target's LUK before the roll: `cri -= target.LUK × (attacker is player ? 2 : 3)`, then rolled against the LUK-derived `cri` value from the Quick Reference section.

**Source:** `battle.cpp:3037-3052` (`is_attack_critical`)

---

## Attack speed (ASPD)

Base attack delay (`amotion`) comes from the job/weapon table, then reduced by AGI and DEX as shown in the AGI section. In this build (`RENEWAL_ASPD` undefined), that percentage reduction *is* the whole ASPD model — there's no separate flat-bonus curve layered on top the way renewal's `status_calc_aspd` works. Percentage skill/status bonuses (Berserk, etc.) apply as straight rate adjustments on top; STR never enters the calculation.

**Source:** `status.cpp:2392-2407` (`status_base_amotion_pc`), `status.cpp:8373-8403+`, `status.cpp:4609`

---

## Max HP / Max SP / Regen

Both stat scalings (`VIT → HP`, `INT → SP`) are the same +1%-per-point formulas shown in the Primary Stats section, and are *not* pre-renewal-specific — this repo has no `#ifdef RENEWAL` branch inside `status_calc_maxhp_pc` / `status_calc_maxsp_pc`. What differs by mode elsewhere (job multipliers, level caps) is level- and job-driven, not stat-driven.

**Source:** `status.cpp:3500-3593`

---

## Casting time

See the DEX entry above — pre-renewal reduces a skill's *entire* cast time by DEX on a straight linear scale to zero at DEX 150 (`battle_config.castrate_dex_scale`). There is no INT contribution and no fixed/variable split; item and skill `castrate`/`add_varcast` bonuses stack on top of the same number afterward.

**Source:** `skill.cpp:20224-20281` (`skill_castfix`)

---

## Status-ailment resistance

Resistance is computed as a rate reduction out of 10,000 (100.00%): `rate -= rate × sc_def/10000; rate -= sc_def2`, then rolled. Duration is reduced the same way via the tick columns where present. All formulas below are the pre-renewal branch of `status_get_sc_def` — renewal collapses most of these into one unified `stat×100 − levelAdvantage` shape, which this build does not use.

| Ailment | Rate reduction (sc_def) | Flat reduction (sc_def2) | Duration reduction |
|---|---|---|---|
| Poison | VIT × 100 | LUK×10 + (target lv − caster lv)×10 | players: VIT×75 rate / LUK×100 flat · mobs: half tick, VIT×200/3 |
| Stun | VIT × 100 | LUK×10 + (target lv − caster lv)×10 | LUK × 10 |
| Silence | VIT × 100 | LUK×10 + (target lv − caster lv)×10 | LUK × 10 |
| Bleeding | VIT × 100 | LUK×10 + (target lv − caster lv)×10 | LUK × 10 |
| Sleep | INT × 100 | LUK×10 + (target lv − caster lv)×10 | LUK × 10 |
| Stone (petrify) | MDEF × 100 | LUK×10 + (target lv − caster lv)×10 | none |
| Freeze | MDEF × 100 | LUK×10 + (target lv − caster lv)×10 | caster's LUK×10 (extends duration) |
| Curse | LUK × 100 (immune at LUK 0) | LUK×10 − caster lv×10 | VIT×100 rate / LUK×10 flat |
| Blind | (VIT + INT) × 50 | LUK×10 + (target lv − caster lv)×10 | LUK × 10 |
| Confusion | (STR + INT) × 50 | caster lv×10 − target lv×10 − LUK×10 *(reversed)* | LUK × 10 |

Both `sc_def` and `sc_def2` are additionally capped at `battle_config.pc_max_sc_def` for player targets.

**Source:** `status.cpp:9634-9747` (`status_get_sc_def`)

---

## Other stat-derived mechanics

- **Carry weight** — `max_weight = job_base + STR × 300`. Identical in both modes. (`status.cpp:3652`)
- **Steal success rate** — `rate = DEX/2 + 2×(base_lv − target_lv) + 10×skill_lv + LUK/2`. (`pc.cpp:6879`)
- **Drop-rate bonus from LUK** — killer's LUK adds to item/zeny drop chance via `battle_config.drops_by_luk` / `drops_by_luk2` (both off by default). (`mob.cpp:2831-2834`)
- **Stat point cost** — raising a stat costs `1 + (current_value + 9)/10` points in pre-renewal, a smooth curve rather than renewal's tiered cost table. (`pc.cpp:8778-8779`)
- **DMOTION (hit-stagger window)** — `clamp(800 − AGI×4, 400, 800)` ms; higher AGI shortens how long you're locked out of acting after being hit. (`status.cpp:4631-4632`)

---

*Every formula above was read directly from this repository's `src/map/` source and cross-checked against the `#ifndef RENEWAL` / `#else` branches to confirm it's the code path this pre-renewal build actually compiles. Line numbers reflect the state of the repo as of this writing and will drift if the source is patched.*
