# Minimal Plan: Enemy Damage + Despawn on 0 HP

## Goal
Implement enemy hit handling so enemy projectiles from players reduce enemy HP, and enemies despawn when HP reaches 0.

## Constraints
- Keep damage math simple, same style as player damage flow.
- No extra systems (no armor, crit, invulnerability, death animation, loot).
- Minimal edits to existing scripts.

---

## 1) Add Simple HP Model to Enemy
**File:** `Scripts/enemy_test.gd`

- Add exported max HP (or reuse current `hp` with clear initialization).
- Keep runtime `hp` float.
- Add method:
  - `take_damage(amount: float)`
  - Logic: `hp = clamp(hp - amount, 0, max_hp)`
  - If `hp <= 0`: despawn via `queue_free()`

This mirrors player simplicity: subtract and clamp.

---

## 2) Route Projectile Hits to Enemy Damage
**File:** `Scripts/projectile.gd`

- Keep existing owner/target group filtering.
- On valid hit:
  - If body in `Players` → keep current SignalBus damage behavior.
  - If body in `Enemies` and has `take_damage` → call `body.take_damage(damage)`.
- Then projectile despawns (`queue_free()`).

---

## 3) Keep Existing Enemy Behaviors
**File:** `Scripts/enemy_test.gd`

- Do not alter movement/separation/melee/shooting behavior.
- Only add HP + death handling.

---

## 4) Validation Checklist
- Player projectiles reduce enemy HP.
- Enemy despawns exactly when HP reaches 0.
- Enemy projectiles still damage players.
- Same-faction projectiles still ignored.
- No regressions in enemy movement/melee/shooting.

---

## Out of Scope
- Enemy hurt/death animations
- Floating damage numbers
- Knockback-on-hit to enemy
- Score/reward drops
- Global enemy health UI
