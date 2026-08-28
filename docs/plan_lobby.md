# Playable LAN Lobby Implementation Plan

## Goal

Replace the Main Menu's waiting-room UI with a playable LAN Lobby where:

- The Host enters the existing gameplay stage immediately after hosting.
- The Joining Peer enters the same stage after connecting successfully.
- Both Participants can move their Player Characters.
- Match systems remain inactive until the Host starts the Match.
- Starting the Match reloads the stage on both devices and uses the existing loading barrier.

The Host currently controls Player Slot 1, but the Session role remains **Host**, not "Player 1."

## Minimal Design

Reuse `Scenes/main.tscn` for both the Lobby and Match. Do not create a second stage or duplicate gameplay nodes.

`NetworkSession.session_state` determines the stage behavior:

- `HOSTING` or `LOBBY`: playable pre-Match Lobby.
- `LOADING`: Match scene is loading and waiting for both peers.
- `IN_MATCH`: normal Match behavior.

When the Host starts the Match, reload `Scenes/main.tscn` on both devices. This provides clean Player positions and fresh Match systems without requiring Lobby-to-Match cleanup logic.

---

## 1) Route Both Participants into the Lobby

**File:** `Scripts/Network/network_session.gd`

Add a narrow state helper:

```gdscript
func is_in_lobby() -> bool:
    return is_online() and session_state in [
        SessionState.HOSTING,
        SessionState.LOBBY,
    ]
```

Update the Session flow:

1. After `host_game()` succeeds, load `Scenes/main.tscn` while state is `HOSTING`.
2. Keep the Joining Peer on the Main Menu while state is `CONNECTING`.
3. After `_protocol_accepted()` changes the Joining Peer to `LOBBY`, load `Scenes/main.tscn` on that device.
4. Keep `start_match()`, `_load_match()`, `scene_ready()`, and `_confirm_match_started()` as the Match-start path.
5. If the Joining Peer disconnects from the Lobby, leave the Host in the stage and return state to `HOSTING`.
6. If either Participant explicitly disconnects, return that device to the Main Menu through `leave_game()`.

Consider renaming `MATCH_SCENE` to `PLAYFIELD_SCENE`, since the same scene will represent both Lobby and Match.

---

## 2) Confirm the Joining Peer Entered the Lobby

**Files:**

- `Scripts/Network/network_session.gd`
- `Scripts/main.gd`

Protocol acceptance does not prove that the Joining Peer finished loading the stage. Add a small Lobby-readiness handshake:

1. The Joining Peer's `main.gd::_ready()` reports that its Lobby scene is ready.
2. The Host records that the Joining Peer entered the Lobby.
3. Enable Start Match only after that report.
4. Reset readiness when the Joining Peer disconnects or the Session ends.

Reuse `lobby_changed(can_start)` for this state rather than adding another public signal. Change its boolean to mean that the Host can safely start the Match.

`start_match()` should also validate Lobby readiness, so a stale or incorrectly enabled button cannot bypass the requirement.

---

## 3) Add the In-World Lobby Interface

**Files:**

- `Scenes/main.tscn`
- `Scripts/main.gd`

Add `LobbyOverlay` under `$HUDs` with:

- Session status text.
- Host LAN address.
- Host presence indicator.
- Joining Peer presence/readiness indicator.
- Host-only Start Match button.
- Disconnect button for both Participants.

In `main.gd::_ready()`:

- If `NetworkSession.is_in_lobby()`, configure Lobby presentation and do not call the Match loading barrier.
- If online and state is `LOADING`, pause and call `NetworkSession.scene_ready()` as currently done.
- Keep Local Co-op behavior unchanged.

Lobby presentation should:

- Keep the scene tree unpaused.
- Show `LobbyOverlay`.
- Hide Match-only HUD such as wave, effects, boss, game-over, victory, and pause UI.
- Configure both Player Slots and controlling peer IDs.
- Refresh when Session state, status, or Lobby readiness changes.
- Reconfigure Player Slot 2 when the Joining Peer connects, because the Host initially loads the stage while `joining_peer_id == 0`.

Lobby actions:

- Start Match calls `NetworkSession.start_match()` and is visible only to the Host.
- Disconnect calls `NetworkSession.leave_game(true, "Disconnected.")`.
- The pause action must not show Match-specific pause text or change `MatchPhase` while in the Lobby.

---

## 4) Add Movement-Only Lobby Behavior

**File:** `Scripts/Player/player.gd`

Add an early Lobby path in `_physics_process()` instead of running the normal Match mechanics.

Lobby movement should only:

- Read movement input.
- Move and animate the Player Character.
- Publish authoritative position and velocity.
- Interpolate replicated movement on the Joining Peer.
- Optionally play footsteps and candle presentation.

Lobby movement must not:

- Consume stamina.
- Sprint into sleep.
- Activate Ghosts.
- Shoot projectiles.
- Apply Timed Item Effects.
- Accept item pickup, drop, or throw commands.
- Apply damage, hit stun, or game-over behavior.

Networking changes:

- Allow `_process_joining_peer_input()` to send movement during Lobby as well as `IN_MATCH`.
- Allow the Host to accept `submit_input()` during Lobby.
- Continue validating generation, sender peer ID, and Player Slot.
- Explicitly reject `submit_interact()` outside `IN_MATCH`.
- Ignore sprint input in Lobby so stamina cannot change.

Before the Joining Peer connects, Player Slot 2 should remain inactive or clearly presented as waiting rather than acting as a second local Player Character.

---

## 5) Disable Match Systems at Their Source

Child `_ready()` methods execute before `main.gd::_ready()`. Therefore, Match systems must reject Lobby activation inside their own modules rather than relying only on the root scene to stop them later.

### Wave Manager

**File:** `Scripts/Spawners/wave_manager.gd`

While in Lobby:

- Stop `Timer` and `StartTimer`.
- Do not assign `Global.wave`.
- Reject `start_wave()`, `try_spawn()`, and timeout handlers.

### Enemy Spawners

**File:** `Scripts/Spawners/spawner.gd`

While in Lobby:

- Do not register in `Global.spawners`.
- Reject `spawn_n()` and `spawn_one()`.

### Item Spawner

**File:** `Scripts/Spawners/item_spawner.gd`

While in Lobby:

- Stop its timer.
- Do not assign `Global.item_spawner`.
- Do not subscribe to Ghost signals.
- Reject `spawn_one()` and its timeout handler.

### OST Manager

**File:** `Scripts/ost_manager.gd`

While in Lobby:

- Do not register as the gameplay OST manager.
- Do not begin Match music progression.

### Replicated Spawn Gate

**File:** `Scripts/main.gd`

Make `spawn_replicated()` reject dynamic spawning while in Lobby. This is the final safety gate for enemies, items, projectiles, and other replicated Match entities.

### Match Processing

**File:** `Scripts/main.gd`

While in Lobby, do not run:

- Total-sleep game-over checks.
- Match effect HUD updates.
- Boss/victory processing.
- Match pause behavior.

---

## 6) Deprecate the Main Menu Lobby UI

**Files:**

- `Scenes/main_menu.tscn`
- `Scripts/main_menu.gd`

The Main Menu remains the Session entry interface, but no longer acts as the Lobby.

Move out of the Main Menu:

- Host waiting status.
- Host LAN address display after hosting.
- Start Match button.
- Host Lobby disconnect controls.

Retain on the Main Menu:

- Host button.
- LAN address entry and Join button.
- `CONNECTING` progress and error messages.
- Cancel/Disconnect while a Joining Peer is still connecting.
- Local Co-op, tutorial, and audio controls.

---

## 7) Match Start Sequence

The final sequence should be:

1. Host enters `HOSTING` and loads the playfield as a Lobby.
2. Joining Peer connects and passes protocol validation.
3. Joining Peer enters `LOBBY` and loads the playfield.
4. Joining Peer reports Lobby readiness.
5. Host's Start Match button becomes enabled.
6. Host calls the existing `start_match()`.
7. Both devices enter `LOADING` and reload `Scenes/main.tscn`.
8. Match modules initialize normally because the scene is no longer in Lobby mode.
9. Both devices report Match scene readiness.
10. Host confirms `IN_MATCH`; the tree unpauses and normal waves begin.

---

## 8) Validation Checklist

### Lobby entry

- Host enters the playfield immediately after successfully hosting.
- Host can move while waiting for a Joining Peer.
- Joining Peer remains on the Main Menu while connecting.
- Joining Peer enters the playfield only after protocol acceptance.
- Start Match remains disabled until the Joining Peer reports Lobby readiness.

### Lobby behavior

- Both Player Characters move correctly on both devices.
- Joining Peer controls only Player Slot 2.
- Host controls only Player Slot 1.
- No stamina is consumed.
- Neither Player Character can sleep or activate a Ghost.
- No projectiles, enemies, items, waves, boss logic, or Match music start.
- Waiting longer than all autostart timer durations still produces no Match activity.
- Match HUD and Match pause messaging remain hidden.

### Match transition

- Start Match is Host-only.
- Starting reloads the stage on both devices.
- Both devices pass the existing Match loading barrier.
- Normal Player mechanics return after `IN_MATCH`.
- Waves, enemies, items, music, pause, game over, and victory behavior still work.

### Disconnects and errors

- Joining Peer disconnect in Lobby leaves the Host waiting in the playfield.
- Host can accept another Joining Peer after a disconnect.
- Host disconnect returns the Joining Peer to the Main Menu.
- Joining Peer can cancel while connecting.
- Connection failure, timeout, protocol mismatch, and full Session still return clear errors.

### Regression

- Local Co-op still enters a normal Match directly.
- Match restart behavior remains unchanged.

---

## Out of Scope

- Internet matchmaking or relay servers.
- Lobby discovery or broadcast-based Host lists.
- More than two Participants.
- Character selection, ready toggles, chat, or Participant names.
- Preserving Lobby positions when the Match starts.
- A separate Lobby stage or duplicated Lobby scene.
- Refactoring the broader gameplay state machine beyond the guards required above.
