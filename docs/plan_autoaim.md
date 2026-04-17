# Minimal Plan: Player Cone Auto-Aim

## Goal
Keep existing auto-shooting, but make fired projectiles auto-aim toward enemies inside a forward cone based on the player's current shooting direction.

If no enemy is in cone, projectile continues straight in `last_move_dir`.

---

## 1) Add Auto-Aim Tunables to Player
**File:** `Scripts/player.gd`

Add exported vars:
- `autoaim_enabled: bool = true`
- `autoaim_range: float` (e.g. 300)
- `autoaim_cone_angle_deg: float` (e.g. 50)

No input changes needed.

---

## 2) Add Target Search Helper (Cone Check)
**File:** `Scripts/player.gd`

Create helper:
- `find_autoaim_target(shoot_dir: Vector2) -> Node2D`

Minimal logic:
1. Get all nodes in `Enemies` group.
2. For each enemy:
   - skip invalid/null nodes.
   - skip if farther than `autoaim_range`.
   - compute angle between `shoot_dir` and direction to enemy.
   - keep only enemies within half cone angle.
3. Choose one best target (minimal: smallest angle, tie-break nearest distance).

---

## 3) Apply Auto-Aim in `shoot_projectile()`
**File:** `Scripts/player.gd`

In `shoot_projectile()`:
- Start with `shot_dir = last_move_dir`.
- If auto-aim enabled, try `find_autoaim_target(last_move_dir)`.
- If target exists, set `shot_dir` toward that target.
- Spawn projectile using `shot_dir` for both spawn offset and projectile direction.

Everything else unchanged.

---

## 4) Keep Scope Minimal
- No homing behavior after firing.
- No new projectile scenes/scripts.
- No enemy-side changes.
- No cone visualization required.

---

## Validation Checklist
- Player facing right can auto-aim only to enemies in right-facing cone.
- Enemies outside cone/behind are ignored.
- If no target in cone, projectile still shoots straight in `last_move_dir`.
- Works for both players because shared `player.gd` is used.
