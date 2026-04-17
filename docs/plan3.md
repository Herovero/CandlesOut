# Minimal Plan: Split Base Enemy (Melee) and New Ranged Enemy

## Goal
Refactor `enemy_test` into a true base/melee enemy (no shooting), then add a separate ranged enemy that:
- has projectile attack only (no melee contact damage),
- approaches players similarly to base enemy,
- keeps a moderate distance once near the player.

## Scope Constraints
- Minimal changes, no deep architecture.
- Reuse existing projectile scene/script.
- Keep current separation behavior.
- No enemy animation/state-machine expansion.

---

## 1) Make `enemy_test.gd` Base + Melee Only
**File:** `Scripts/enemy_test.gd`

### Keep
- player targeting (`find_closest_player`)
- movement toward target
- separation logic
- HP + `take_damage`
- melee contact damage in `_on_hitbox_body_entered`

### Remove
- projectile exports/vars
- cooldown vars
- `shoot_projectile()`
- auto-shoot block in `_physics_process`

Result: `enemy_test.gd` becomes the shared chase/melee base behavior.

---

## 2) Add New Ranged Enemy Script Extending Base
**New file:** `Scripts/enemy_ranged.gd`

Use inheritance:
- `extends "res://Scripts/enemy_test.gd"`

### Override/adjust behavior minimally
- Disable melee contact damage (override `_on_hitbox_body_entered` to do nothing).
- Add ranged exports:
  - `projectile_scene`, `shoot_interval`, `projectile_speed`, `projectile_damage`, `muzzle_offset`
  - `preferred_distance` (moderate range)
  - `distance_tolerance` (small deadzone to avoid jitter)

### Distance movement rule (minimal)
Given distance to target:
- If `distance > preferred_distance + tolerance` → move toward player.
- If `distance < preferred_distance - tolerance` → move away from player.
- Else (inside band) → stop/slow and shoot.

Keep existing separation influence so ranged enemies don’t stack.

### Shooting rule
- Fire on cooldown when target exists (and ideally while inside/near preferred band).
- Projectile setup:
  - `owner_group = "Enemies"`
  - `target_group = "Players"`
  - direction toward player (or last move dir fallback)

---

## 3) New Ranged Enemy Scene
**New file:** `Scenes/enemy_ranged.tscn`

Minimal node setup by duplicating `enemy_test.tscn` and changing:
- script → `enemy_ranged.gd`
- keep group `Enemies`
- keep collision/hitbox nodes if needed for body collisions and physics

No melee effect should occur because ranged script overrides melee callback.

---

## 4) Spawn/Placement Hook
Use whichever is fastest for testing:
- place `enemy_ranged.tscn` directly in `main.tscn`, or
- add to spawner list (if already easy).

No spawning system rewrite.

---

## 5) Validation Checklist
- Base `enemy_test` no longer shoots.
- Base `enemy_test` still does melee + chase + separation + HP/despawn.
- Ranged enemy shoots projectiles.
- Ranged enemy does **not** deal melee contact damage.
- Ranged enemy tries to hold moderate distance (approach if far, back off if too close).
- Enemy projectiles still damage players correctly.

---

## Out of Scope
- Complex FSM/behavior trees
- Strafing/pathfinding upgrades
- New VFX/animations
- Advanced kiting tactics
