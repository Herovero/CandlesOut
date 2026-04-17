# Minimal Boss Plan

## Goal
Add one simple boss that feels like a final encounter without building new systems.

## Scope
- One boss enemy
- High HP
- Two attack patterns only:
  1. Radial burst
  2. Charge
- Simple state cycle: Idle -> Attack1 -> Attack2

## 1) Add Boss Scene + Script
- `Scenes/enemy_boss.tscn`
- `Scripts/enemy_boss.gd`

Reuse existing enemy/projectile approach where possible.

## 2) Boss Basics
- Larger visual/collider than normal enemies.
- Higher health values.
- Uses same simple damage model (`take_damage`, clamp, despawn at 0).

## 3) Boss State Logic (Minimal)
States:
- `IDLE` (short pause)
- `ATTACK_RADIAL`
- `ATTACK_CHARGE`

Cycle sequentially (not complex/randomized FSM).

## 4) Attack 1: Radial Burst
- Spawn projectiles in fixed directions (e.g., 8-way).
- Use shared `projectile.tscn`.
- Enemy-owned bullets target players.

## 5) Attack 2: Charge
- Brief wind-up/telegraph delay.
- Lock direction to nearest player.
- Dash for short duration at high speed.
- Return to idle afterward.

## 6) Integration (Minimal)
- Spawn boss manually first for testing (scene placement or simple spawn call).
- Later hook to gamestate boss trigger.
- On boss death, call existing win/end hook (or placeholder signal).

## 7) Validation Checklist
- Boss can be damaged and die.
- Radial burst fires correctly and can hurt players.
- Charge executes with delay and movement burst.
- State cycle repeats without freezing.

## Out of Scope
- Complex AI systems
- Advanced pathfinding
- Extra boss phases
- Refactoring enemy architecture
