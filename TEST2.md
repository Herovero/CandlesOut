A 3-day plan means you cannot build “systems,” you build the **minimum loop + just enough variation to feel complete**. Anything reusable or extensible is secondary.

Your scope reduces to:

* 2 enemy types (chaser + one variant)
* 1 boss (simple patterns)
* Basic animation + feedback
* 1–2 “losing control” hooks that affect enemies (optional if time dies)

Everything else is cut.

---

# Day 1 — Playable Combat Core (non-negotiable)

**Objective:** A fully playable loop with one enemy.

### 1. Enemy Base (finish this first)

Implement ONE script that does:

* Find nearest player
* Move toward player
* Deal collision damage
* Take damage + die

**Do not abstract. Hardcode if needed.**

Core logic:

* `target = nearest_player()`
* `dir = (target.pos - self.pos).normalized()`
* `velocity = dir * speed`

Add:

* HP variable
* On hit → reduce HP → if ≤0 → die

---

### 2. Knockback (must feel good)

On hit:

* Apply force vector away from bullet
* Store as `knockback_velocity`
* Decay over time

Movement becomes:

```
final_velocity = move_velocity + knockback_velocity
knockback_velocity *= 0.85
```

---

### 3. Basic Animation Hook

Don’t overbuild FSM. Just:

* if moving → play "walk"
* else → "idle"
* on hit → flash red
* on death → play death → delete

---

### 4. Integration with Shooting

Make sure:

* Bullets damage enemies
* Enemies actually die
* Knockback visible

**End of Day 1 milestone:**

* You can run around and kill enemies
* It feels responsive

If this is not done, you are behind.

---

# Day 2 — Variety + Pressure

**Objective:** Make gameplay interesting with minimal additions

---

### 1. Second Enemy Type (Ranged)

Clone base enemy, modify behavior:

* Stop when within distance
* Shoot projectile toward player

Logic:

```
if distance > attack_range:
    move toward player
else:
    stop and shoot on cooldown
```

No fancy aiming. Just direct vector.

---

### 2. Basic Enemy Spacing (cheap “flocking”)

Do NOT implement full flocking.

Instead:

* If too close to another enemy → push away slightly

```
for nearby_enemy:
    if distance < threshold:
        velocity += (self.pos - other.pos).normalized() * small_force
```

That’s enough to prevent clumping.

---

### 3. Attack Variety

Now you have:

* Chaser (pressure)
* Ranged (zone control)

That’s sufficient.

---

### 4. Death Feedback

Add:

* Small delay before delete
* Optional: spawn effect (if easy)

---

### 5. Animation Completion

Ensure:

* Walk works for both enemy types
* Attack animation triggers for ranged
* Hurt flash works consistently

---

**End of Day 2 milestone:**

* Two enemy types
* Combat feels dynamic
* No major bugs

---

# Day 3 — Boss + Stabilization

**Objective:** Finish the game, not polish it

---

### 1. Boss (keep it extremely simple)

Do NOT design a complex boss.

Use:

* Big enemy
* High HP
* 2 attack patterns

**Pattern 1: Radial burst**

* Shoot bullets in all directions every X seconds

**Pattern 2: Charge**

* Dash toward player after short delay

That’s it.

---

### 2. Boss Logic

State-based but simple:

States:

* Idle (short)
* Attack1
* Attack2

Cycle randomly or sequentially.

---

### 3. Boss Integration

* Trigger from gamestate
* Ensure it:

  * Takes damage
  * Dies properly
  * Ends game

---

### 4. Final Pass (critical)

Fix only:

* Bugs that stop gameplay
* Broken animations
* Performance (too many enemies)

Do NOT:

* Add new features
* Refactor code

---

# Time Allocation (strict)

**Day 1**

* Enemy base: 3–4h
* Knockback: 1h
* Animation + integration: 2–3h

**Day 2**

* Ranged enemy: 3h
* Spacing logic: 1h
* Polish combat: 2–3h

**Day 3**

* Boss: 4–5h
* Integration + fixes: remaining time

---

# Hard Constraints (follow these or you won’t finish)

* Max 2 enemy types + 1 boss
* No full FSM system
* No real flocking system
* No advanced AI
* No refactoring after Day 2

---

# If you fall behind

Cut in this order:

1. Remove ranged enemy → keep only chaser
2. Simplify boss → just big chaser with more HP
3. Remove spacing logic

Game still ships.

---

# What you should start with (immediately)

1. Implement chaser enemy
2. Make bullets kill it
3. Add knockback
4. Hook animations

Do not touch anything else until this works end-to-end.
