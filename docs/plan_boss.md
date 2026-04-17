# Boss Implementation Plan

## Goal
Implement one boss enemy that feels like a proper final fight with **randomized attack selection** and **3 simple attack patterns**, while keeping code jam-minimal.

## Scope
- One boss enemy
- High HP
- 3 attacks:
  1. Radial burst (projectile pattern)
  2. Charge (2 hearts damage)
  3. Cone melee slash in facing direction (2 hearts damage)
- Randomized state flow: `IDLE -> (random attack) -> IDLE -> ...`

---

## 1) Files
- `Scenes/enemy_boss.tscn`
- `Scripts/enemy_boss.gd`

Reuse current systems where possible:
- player damage signal / `receive_hit`
- shared `projectile.tscn`
- existing enemy movement style as base reference

---

## 2) Boss Core Setup
- Larger sprite/collision than normal enemies.
- Higher health (`max_hp`, `hp`, `take_damage`) using same simple subtraction/clamp model.
- Join `Enemies` group so player targeting/projectiles continue to work.

---

## 3) Boss State Logic (Randomized, Minimal)
States:
- `IDLE` (short delay)
- `ATTACK_RADIAL`
- `ATTACK_CHARGE`
- `ATTACK_CONE`

Flow:
1. Enter `IDLE` for a short timer.
2. Pick one of the 3 attacks randomly (optional: avoid repeating the immediately previous attack).
3. Execute attack.
4. Return to `IDLE`.

No full FSM framework needed; a small enum + match + timers is enough.

---

## 4) Attack Details

### Attack 1: Radial Burst
- Spawn projectiles in fixed spread (e.g., 8 directions).
- Use shared `projectile.tscn`.
- Set owner/target groups:
  - `owner_group = "Enemies"`
  - `target_group = "Players"`

### Attack 2: Charge (2 hearts)
- Brief telegraph/wind-up.
- Lock direction toward nearest player at charge start.
- Dash for short duration at high speed.
- On collision with player during charge: deal **2 hearts** damage.

### Attack 3: Cone Melee (2 hearts)
- Short telegraph.
- Use facing direction to define a forward cone.
- Damage players inside cone once per attack execution.
- Damage amount: **2 hearts**.

---

## 5) Integration
- First: place boss manually in test scene for behavior tuning.
- Then: hook to gamestate boss trigger.
- On boss death: call win/end flow (or emit a boss-dead signal consumed by gamestate).

---

## 6) Validation Checklist
- Boss spawns and can take damage/die correctly.
- Attack selection is randomized across the 3 attack types.
- Radial projectiles fire correctly and damage players.
- Charge attack deals 2 hearts and has visible wind-up.
- Cone attack deals 2 hearts only in forward cone region.
- Boss returns to idle between attacks and does not freeze.

---

## Out of Scope
- Multi-phase boss transformation
- Complex behavior trees/pathfinding
- New reusable AI framework
- Major refactors of enemy architecture
