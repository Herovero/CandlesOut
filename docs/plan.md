# Minimal Implementation Plan: Shared Auto-Shooting for Players + Enemies

## Goal
Enable both **players** and **enemies** to auto-shoot using the same projectile system, with shots fired in the actor's current walking direction.

## Scope Constraints
- Keep it minimal and jam-friendly.
- No manual input for shooting.
- No enemy damage/death implementation yet.
- Preserve existing melee enemy behavior.

---

## 1) Keep One Shared Projectile (small refactor only)
**Files:**
- `Scripts/projectile.gd`
- `Scenes/projectile.tscn`

**Plan:**
- Keep projectile movement/lifetime logic as-is.
- Keep faction filtering via `owner_group` and `target_group`.
- Ensure hit behavior is minimal:
  - If target is in `Players` group → emit `SignalBus.take_damage(damage, input_prefix)`.
  - If target is in `Enemies` group → do nothing for now (placeholder path only, no damage/death).
- Keep projectile visual shared for now (`icon.svg`).

---

## 2) Add Auto-Shooting to Player
**File:** `Scripts/player.gd`

**Plan:**
- Add shooting exports/vars similar to enemy for consistency:
  - `projectile_scene`, `shoot_interval`, `projectile_speed`, `projectile_damage`, `muzzle_offset`
  - cooldown var and `last_move_dir`
- Track move direction each frame:
  - If movement direction is non-zero, update `last_move_dir`.
- Auto-fire rule:
  - While player is awake and moving, fire on cooldown in `last_move_dir`.
  - No input action required.
- Spawn projectile with:
  - `owner_group = "Players"`
  - `target_group = "Enemies"`
  - direction/speed/damage from player exports

---

## 3) Keep Enemy Shooting Compatible
**File:** `Scripts/enemy_test.gd`

**Plan:**
- Keep existing auto-shoot behavior (already movement-based).
- Ensure enemy projectiles continue using:
  - `owner_group = "Enemies"`
  - `target_group = "Players"`

---

## 4) Validation Checklist (No Feature Creep)
- Player auto-shoots while walking.
- Enemy auto-shoot still works.
- Player projectiles do not hurt players.
- Enemy projectiles do not hurt enemies.
- Player projectiles can collide with enemies but do not process enemy HP/death yet.
- No input bindings added for shooting.

---

## 5) Out of Scope (for later)
- Enemy HP reduction from projectile hits.
- Enemy death/animation/VFX on death.
- Projectile sprite/animation variants by shooter.
- Weapon upgrade systems or fire pattern complexity.
