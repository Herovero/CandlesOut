# Multiplayer Audio and Joiner Smoothing Plan

## Goal

Fix two role-dependent Online Co-op problems while retaining the Host-authoritative simulation:

- The Joining Peer must hear gameplay music and sound effects.
- The Joining Peer must see smooth movement and receive responsive local controls.
- Local Co-op behavior must remain unchanged.

This is a focused follow-up to `MULTIPLAYER_PLAN.md`. It does not move gameplay authority to the Joining Peer or introduce rollback networking.

## Current Problems

### Gameplay audio

The Host owns gameplay simulation, and most audio playback currently occurs inside Host-only code. The Joining Peer loads the gameplay scene but receives no presentation event telling it to start music or play one-shot effects.

Different audio categories need different replication strategies:

- Music is durable presentation state.
- Footsteps and similar continuous sounds can be derived from synchronized movement.
- Shots, impacts, deaths, attacks, and item effects are one-shot presentation events.

### Joiner movement

The Joining Peer sends input at 30 Hz, the Host simulates it, and transforms are synchronized at 20 Hz. The Joining Peer applies synchronized positions directly. There is currently no interpolation, prediction, or reconciliation, so remote movement visibly steps and the Joining Peer's own controls wait for a network round trip.

## Constraints

- The Host remains authoritative for movement, collisions, damage, enemies, projectiles, items, waves, and random outcomes.
- Audio and smoothing must never mutate gameplay state.
- Presentation events must include `match_generation` and reject stale generations.
- Existing Local Co-op must not require an active network Session.
- Do not synchronize animation frames or send network packets for every footstep.

## 1. Add a Gameplay Audio Module

Create a module at:

```text
Scripts/Audio/gameplay_audio.gd
```

Give callers a small interface:

```gdscript
play_sfx(cue, world_position, variant_seed)
play_wave_music(wave_number)
stop_music()
```

The implementation owns the cue-to-stream catalog, creates and cleans up positional `AudioStreamPlayer2D` instances, and delegates music playback to the active `ost_manager`. Use a cue enum rather than accepting resource paths over the network.

Example cue categories:

- Player shoot, block, sleep, and hit
- Enemy footstep, shoot, attack, damage, and death
- Boss attack cues
- Item pickup, throw, success, and Backfire
- Projectile impact and bomb explosion

Keep random pitch or sample selection deterministic per event by sending a small `variant_seed`, or choose it independently on each peer when exact matching is unimportant.

## 2. Replicate Audio Correctly

Put the stable Match-scoped RPC receiver on the `NetworkSession` autoload. Gameplay callers should not implement their own nearly identical RPC wrappers.

### Music

Music transitions are durable and infrequent. Broadcast them reliably and execute them locally on the Host as well:

```gdscript
@rpc("authority", "call_local", "reliable")
func _receive_music_state(generation: int, wave_number: int) -> void:
    if generation != match_generation:
        return
    GameplayAudio.play_wave_music(wave_number)
```

Provide equivalent reliable events for stopping music and Match-ending transitions. Replace Host-only music calls in:

```text
Scripts/Spawners/wave_manager.gd
Scripts/ost_manager.gd
```

The Joining Peer must start the same wave music after the loading barrier and stop it during restart, disconnect, victory, game over, and return to menu.

### Continuous sounds

Derive footsteps locally from synchronized velocity and presentation state. Update the Joining Peer presentation path in:

```text
Scripts/Player/player.gd
Scripts/Player/player_audio.gd
Scripts/Enemy/*.gd
```

Each peer should call its local footstep handler while the presented entity is moving. Do not send footstep RPCs.

### One-shot effects

The Host emits one-shot cues through a single interface such as:

```gdscript
NetworkSession.broadcast_sfx(cue, world_position, variant_seed)
```

Internally, use an authority-only, call-local, unreliable RPC for short-lived effects:

```gdscript
@rpc("authority", "call_local", "unreliable")
func _receive_sfx(
    generation: int,
    cue: GameplayAudio.Cue,
    world_position: Vector2,
    variant_seed: int
) -> void:
    if generation != match_generation:
        return
    GameplayAudio.play_sfx(cue, world_position, variant_seed)
```

Unreliable delivery prevents old effects from arriving late. Missing an effect may reduce polish but cannot affect gameplay. Music and lifecycle transitions remain reliable.

Replace direct Host-only one-shot playback in Player Character, enemy, boss, projectile, and item scripts. In Local Co-op, the same interface plays locally without using an RPC. Ensure `call_local` does not cause duplicate Host playback.

## 3. Interpolate Replicated Movement

Interpolation is the first movement fix and should be completed before prediction.

For moving replicated entities, synchronize target presentation state instead of writing network snapshots directly into the displayed transform:

```gdscript
var network_position: Vector2
var network_velocity: Vector2
```

The Host updates these values after authoritative movement. The Joining Peer moves the presented entity toward `network_position` every rendered or physics frame using frame-rate-independent interpolation:

```gdscript
var weight := 1.0 - exp(-interpolation_speed * delta)
position = position.lerp(network_position, weight)
```

Add a snap-distance threshold for teleports, initial spawn placement, Ghost activation, scene reloads, and large corrections. Derive animation direction and continuous audio from `network_velocity`.

Apply this to:

- Both Player Characters as viewed remotely
- Ghosts
- Enemies and the boss
- Projectiles
- Thrown or otherwise moving items

Do not interpolate health, phase changes, item ownership, or other discrete state.

Change the initial moving-state replication interval in `NetworkSession.configure_synchronizer()` from 20 Hz to 30 Hz only after interpolation is in place:

```gdscript
const REPLICATION_INTERVAL := 1.0 / 30.0
```

Keep the rate named and centralized. Increasing the rate alone is not an interpolation substitute.

## 4. Add Joining-Peer Prediction and Reconciliation

Implement this only after measuring the interpolated build. It addresses control latency for the Joining Peer's own Player Character; interpolation addresses visible stepping.

### Input commands

Add a monotonically increasing sequence number to Joining Peer movement commands:

```gdscript
submit_input(generation, sequence, direction, sprinting)
```

The Joining Peer stores unacknowledged commands in a bounded queue and immediately applies local commands through the existing `apply_command()` simulation path.

### Host acknowledgement

The Host validates and applies commands as it does now, then synchronizes:

- Authoritative position
- Authoritative velocity
- Authoritative stamina and movement-affecting state
- Last processed input sequence

### Reconciliation

When an authoritative snapshot arrives, the Joining Peer:

1. Removes acknowledged commands from its queue.
2. Compares predicted and authoritative state.
3. Smoothly corrects small visual errors.
4. Resets to authoritative state and replays unacknowledged commands after a large error.
5. Snaps immediately for teleports, sleeping transitions, prison effects, knockback, restart, or generation changes.

Prediction must not apply damage, enemy collisions, item outcomes, projectile hits, or other authoritative decisions locally. The Host's result always wins.

## 5. Protocol and Lifecycle

Increment `PROTOCOL_VERSION` when the new RPC and input formats are introduced so old builds cannot join new builds.

Clear all new state on Match or Session reset:

- Pending audio cues
- Current music state
- Interpolation targets
- Prediction input sequence
- Unacknowledged command queue
- Reconciliation error and correction velocity

Do not allow cues or snapshots from an earlier `match_generation` to affect the current Match.

## Implementation Order

1. Add the `GameplayAudio` cue catalog and local playback interface.
2. Add reliable replicated music state.
3. Derive Player Character and enemy footsteps locally from synchronized movement.
4. Route one-shot gameplay effects through the centralized audio-event RPC.
5. Add target transform properties and interpolation for Player Characters and Ghosts.
6. Extend interpolation to enemies, projectiles, and moving items.
7. Raise moving-state replication from 20 Hz to 30 Hz and profile bandwidth.
8. Test both devices in both Host and Joining Peer roles.
9. Add Joining Peer prediction, input acknowledgements, and reconciliation only if local control latency remains unacceptable.
10. Increment the protocol version and verify complete lifecycle cleanup.

## Verification

### Audio

- Both peers hear wave intros and music transitions at the correct time.
- Both peers hear Player Character, enemy, boss, projectile, and item effects.
- Footsteps follow visible movement without generating network events.
- The Host does not hear duplicate sounds from `call_local` RPCs.
- Disconnect, restart, victory, game over, and return to menu stop or replace music correctly.
- Local Co-op audio remains unchanged.

### Movement

- At 20 Hz and 30 Hz replication, remote movement renders smoothly every frame instead of stepping at snapshot frequency.
- Spawn, teleport, sleep, Ghost activation, knockback, and restart do not slowly interpolate from invalid old positions.
- With approximately 50–100 ms artificial latency, remote entities remain smooth.
- Packet loss and jitter do not permanently displace an entity.
- After prediction is added, the Joining Peer's own movement responds on the next local frame.
- Reconciliation converges to Host state without sustained oscillation.
- Host and Joining Peer agree on collisions, health, stamina, effects, and Match outcomes.

### Role reversal

Run the same checks twice, swapping which physical device is Host. Audio and smoothness must follow neither the device nor the role; both peers should receive equivalent presentation while the Host remains the only gameplay authority.

## Completion Criteria

This follow-up is complete when:

- The Joining Peer hears all gameplay audio categories.
- Neither role has duplicate or stale audio.
- Replicated movement is interpolated for every moving gameplay entity.
- The Joining Peer's own controls meet the agreed LAN responsiveness target, with prediction added if interpolation alone is insufficient.
- Both Host/Joining Peer role assignments pass the verification matrix.
- Local Co-op and repeated Session lifecycle tests remain functional.
