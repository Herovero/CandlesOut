# Minimal Plan: 4 Ranged-Enemy Balance Features

Based on `new addition log`, implement only these 4 ranged-enemy items:
1. Ranged enemy lower HP
2. Ranged enemy does NOT move away when player gets close
3. Ranged enemy shoots less frequently
4. Ranged enemy has limited shoot range (not infinite)

## Scope Rules
- Modify only ranged enemy behavior/data.
- Do not add new systems.
- Do not change melee enemy behavior.

---

## 1) Lower Ranged HP
**File:** `Scripts/enemy_ranged.gd`

- Override/export `max_hp` for ranged with lower default than melee base.
- Keep existing `take_damage` from base (`enemy_test.gd`) unchanged.

Minimal target: ranged dies faster than base enemy.

---

## 2) Remove Back-Off Behavior (No Move Away)
**File:** `Scripts/enemy_ranged.gd`

Current behavior includes moving away when too close.
Change to:
- If target distance is greater than preferred distance -> move toward target.
- Otherwise -> stop/hold position (no retreating).

This makes ranged enemies less slippery and easier to pressure.

---

## 3) Reduce Fire Frequency
**File:** `Scripts/enemy_ranged.gd`

- Increase `shoot_interval` default value (slower rate of fire).
- Keep cooldown logic identical; only tune the number.

No new timers/states.

---

## 4) Add Shooting Range Cap
**File:** `Scripts/enemy_ranged.gd`

- Add export `shoot_range`.
- Only fire when:
  - target exists, and
  - `distance_to_target <= shoot_range`, and
  - cooldown ready.

Enemy can still approach while out of range, but won’t shoot across the map.

---

## Validation Checklist
- Ranged enemy HP is lower than melee enemy HP.
- When player gets too close, ranged enemy no longer retreats.
- Ranged enemy fires more slowly.
- Ranged enemy does not shoot when player is outside `shoot_range`.
- Base/melee enemy behavior remains unchanged.

## Out of Scope
- Ranged-specific animations
- New projectile types
- Flocking/refactor changes
- Global spawn/wave rebalance
