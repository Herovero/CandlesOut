# Multiplayer Implementation Plan

## Goal

Add Terraria-style host-and-join multiplayer to the existing two-player co-op game without removing local co-op:

- Local Co-op continues to support two Participants on one machine.
- Online Co-op runs between two native desktop builds on the same LAN.
- One Participant is the Host and also plays.
- The remote Participant is the Joining Peer.
- The Host runs the authoritative game simulation.
- Both Participants see and interact with the same world.

## Initial Scope

The first version should intentionally support only:

- Native Windows and Linux desktop builds, including cross-platform LAN Sessions
- IPv4 LAN addresses only
- Local Co-op with both Participants on one machine
- Online Co-op with one Host and one Joining Peer on the same LAN
- Joining by entering the Host's LAN IP address
- Both Online Co-op Participants connecting before the Match starts
- Host-controlled pause, restart, waves, and scene changes in Online Co-op
- Ending an Online Co-op Match if either peer disconnects

The following are out of scope:

- Internet multiplayer, NAT traversal, port forwarding, or UPnP
- Session passwords, authentication, or transport encryption
- Automatic LAN host discovery
- Web multiplayer
- Joining a match already in progress
- Reconnection and host migration
- More than two Player Slots or Participants
- Steam lobbies and relay networking
- Full client-side prediction

## Authority Model

Use a **host-authoritative simulation**. The Joining Peer sends input intentions to the Host, and the Host decides the resulting game state.

| State | Authority |
|---|---|
| Player Character movement and stamina | Host |
| Health and damage | Host |
| Enemy AI and health | Host |
| Projectiles and collisions | Host |
| Ghost activation and movement | Host |
| Item spawning and outcomes | Host |
| Waves and boss phases | Host |
| Music, particles, UI, and sound | Local presentation of replicated state |

This prevents the two machines from diverging because of random item effects, enemy targeting, collisions, boss behavior, and timing differences.

## 1. Add a Networking Module

Create an autoload at:

```text
Scripts/Network/network_session.gd
```

Give it a small interface:

```gdscript
host_game()
join_game(address)
leave_game()
start_match()
```

Use Godot's `ENetMultiplayerPeer`:

```gdscript
extends Node

const LAN_PORT := 7000
const PROTOCOL_VERSION := 1

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func host_game() -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(LAN_PORT, 1) # One client plus the host
    if error == OK:
        multiplayer.multiplayer_peer = peer
    return error

func join_game(address: String) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, LAN_PORT)
    if error == OK:
        multiplayer.multiplayer_peer = peer
    return error
```

Godot assigns peer ID `1` to the server. The Joining Peer receives another peer ID. The fixed UDP port is a developer constant and is not configurable through the normal UI.

After transport connection, exchange `PROTOCOL_VERSION` before accepting the Joining Peer into the Lobby. Reject mismatches with a clear “Game versions do not match” message. Compatibility is based on this protocol version rather than an unrelated save or display version.

Update `Scripts/main_menu.gd` and its scene with three explicit modes:

- Local Co-op
- Host LAN Game
- Join LAN Game

The LAN flow also needs:

- Display of the Host's likely IPv4 LAN address
- Validated manual IPv4 LAN-address field for the Joining Peer
- Connection status
- Host-only Start button after the Joining Peer connects
- Connection failure and disconnection messages

Do not implement automatic LAN discovery in the first version. The existing Boss button is a development shortcut, not a normal release mode; hide it in release builds. In debug builds only, expose a clearly marked `Debug: Host Boss Match` control that can start Local Co-op at the boss or configure the Host's next Online Co-op Match to start there.

ENet uses UDP. This plan only supports peers that can reach each other on the same LAN; internet discovery, NAT traversal, and relay transports are intentionally excluded.

## 2. Assign Peers to the Existing Player Characters

For the first version, keep the existing `Player1` and `Player2` Player Character nodes in `main.tscn`.

For Online Co-op, assign control when the match starts:

```text
Player1.controlling_peer_id = 1
Player2.controlling_peer_id = joining_peer_id
```

The Host always occupies Player Slot 1 and the Joining Peer always occupies Player Slot 2. Local Co-op keeps both slots on one machine.

Player Slot is the exclusive gameplay identity for health, damage, item and Ghost ownership, effects, and HUD targeting. Peer IDs are transport identities used only to authorize which Online Co-op Participant may submit input for a Player Slot.

Separate Player Slot identity from input bindings. `input_prefix` currently serves both purposes.

Introduce explicit identity fields:

```gdscript
var player_slot: int
var controlling_peer_id: int
```

Online Co-op should use generic local actions such as:

```text
move_left
move_right
move_up
move_down
sprint
interact
```

Bind that generic action set to the local keyboard and controller device `0`, allowing either device to control the machine's one Online Co-op Participant. The Host associates received input with its sender's peer ID.

Preserve the existing two keyboard layouts and controller assignments for Local Co-op behind a separate local-dual-input adapter so Player Character simulation does not need to know which mode supplied a command.

## 3. Separate Input Collection from Simulation

`Scripts/Player/player.gd` currently reads `Input` and immediately updates the body. Split those responsibilities behind functions such as:

```gdscript
func sample_local_input() -> PlayerCommand
func apply_command(command: PlayerCommand, delta: float) -> void
```

Local Co-op, Host input, and Joining Peer input must all converge on the same `apply_command` simulation path. Input adapters may differ, but there must not be separate local and network implementations of movement, sprinting, sleeping, or interaction rules.

The Joining Peer sends movement intentions to the Host with the current Match generation:

```gdscript
submit_input.rpc_id(1, NetworkSession.match_generation, direction, sprinting)
```

The Host rejects stale generations, validates the sender, and stores the latest input:

```gdscript
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(generation: int, direction: Vector2, sprinting: bool) -> void:
    if not multiplayer.is_server():
        return
    if generation != NetworkSession.match_generation:
        return

    var sender := multiplayer.get_remote_sender_id()
    if sender != controlling_peer_id:
        return

    latest_direction = direction.limit_length(1.0)
    latest_sprinting = sprinting
```

Use unreliable ordered messages for continuous movement because newer input supersedes older input. The Joining Peer sends input continuously at an initial rate of 30 Hz, even when unchanged. If the Host receives no input update for 500 ms, it substitutes neutral movement and disables sprint until fresh input arrives. Losing window focus should immediately send neutral input when possible.

Use validated reliable Joining Peer requests for discrete Player Character actions:

- Pick up item
- Drop item
- Throw item

Pause, Restart, Rematch, and Return to Main Menu are Host-owned lifecycle transitions, not Joining Peer gameplay requests. Joining Peer Disconnect closes its local peer and is observed through the connection lifecycle.

Initially, accept the input delay caused by waiting for the Host. Client prediction and reconciliation are not part of this plan; if LAN playtesting proves them necessary, define them as a separate follow-up project.

## 4. Synchronize Player Character State

Add a `MultiplayerSynchronizer` to each Player Character.

Synchronize authoritative properties including:

- Position and velocity
- Health
- Stamina
- Sleeping and returning states
- Invincibility and status effects
- Ghost activation and return state
- Animation-relevant state

Run authoritative physics at 60 Hz, initially synchronize moving transforms at 20 Hz, and interpolate remote positions to avoid visible snapping. Keep input and synchronization rates as named developer constants rather than runtime settings, and adjust them only after profiling.

Give each Player Slot one persistent Ghost node with a stable scene path. While its Player Character is awake, the Ghost is inactive, invisible, and non-colliding. The Host activates and positions it when the Player Character sleeps, synchronizes its movement and state, then deactivates it after the return animation. Do not dynamically spawn or destroy Ghosts.

Derive animations and visual effects locally from synchronized state where possible. Avoid synchronizing individual animation frames every network update.

Both machines continue to display health, stamina, and active status effects for both Player Slots. The shared HUD observes synchronized state and remains identical on both peers.

## 5. Make World Simulation Host-Only

Only the host should make gameplay decisions in:

- `Scripts/Spawners/wave_manager.gd`
- `Scripts/Spawners/item_spawner.gd`
- `Scripts/Enemy/*.gd`
- `Scripts/projectile.gd`
- Bomb and item-effect scripts
- Boss phase logic
- Game-over checks in `Scripts/main.gd`

Do not allow the Joining Peer to run independent enemy AI, damage checks, spawning, or wave progression.

Split authoritative simulation from visual presentation rather than disabling entire scripts on the Joining Peer. The Joining Peer still needs to render animations, particles, sounds, and interpolated movement.

All random decisions must occur on the Host, including:

- Wave queue shuffling
- Weighted item selection
- Item Backfire outcomes
- Bomb behavior
- Boss attack selection
- Random spawn positions

The Host also owns every gameplay clock: cooldowns, effect durations, stamina, wave delays, boss transitions, and projectile lifetimes. The Joining Peer may animate synchronized remaining time, but its local timer or `await` must never expire or advance authoritative gameplay state. Global Host pause freezes these authoritative clocks.

## 6. Replicate Dynamic Objects

Use `MultiplayerSpawner` for dynamically created objects:

- Enemies
- Projectiles
- Items, including bombs

Place replicated objects under a stable world node such as:

```text
Main/ReplicatedEntities
```

The Host creates and removes these objects. Their scenes can contain `MultiplayerSynchronizer` nodes for position and gameplay state. Commit to Godot's `MultiplayerSpawner` and `MultiplayerSynchronizer` for the first version rather than building a custom snapshot or entity-replication protocol.

Set an entity's identifying and initial authoritative state before exposing it through `MultiplayerSpawner`, using custom spawn data where necessary. The Joining Peer must never temporarily simulate a projectile, enemy, item, or bomb with default ownership, direction, phase, or damage values.

Synchronizing every projectile is acceptable for the first version because the game has relatively few entities. Optimize only after profiling.

## 7. Move Health Out of the HUD

`Scripts/Item/heart.gd` currently owns Player Character health. Gameplay state should not live in presentation code.

Move health directly into `Scripts/Player/player.gd`, alongside stamina, sleeping, and status effects:

```gdscript
var health := 5.0
var max_health := 5.0

func apply_damage(amount: float) -> void:
    health = clampf(health - amount, 0.0, max_health)
```

The Host applies damage and healing. The heart HUD only observes and displays synchronized health.

Each Player Slot can have at most one Timed Item Effect. Applying a new Timed Item Effect first performs complete authoritative cleanup of the previous one, then applies the new effect and duration. Timed Item Effects continue counting down while a Player Character sleeps or its Ghost is controlled, freeze during global Host pause, and clear when the Match ends or restarts. Hit stun, damage invincibility, knockback, sleeping, and Ghost transitions are Intrinsic Player States rather than Timed Item Effects and do not participate in this replacement rule.

Replace string identifiers such as `"p1_"` in damage and item signals with Player Slots. Do not use peer IDs as gameplay targets.

## 8. Avoid Reparenting Held Items

`Scripts/Item/item.gd` currently reparents held items between the world and a Ghost. Scene-tree reparenting is difficult to replicate reliably.

Keep items under the stable replicated world node and represent their authoritative lifecycle explicitly:

```gdscript
enum ItemState { WORLD, HELD, THROWN }
var item_state := ItemState.WORLD
var held_by_slot := 0
```

`WORLD` items are available for pickup, `HELD` items logically follow a Player Slot's active Ghost, and `THROWN` items move through the world. Consumption or cleanup removes the item through authoritative replicated despawning; scene-tree parentage never represents gameplay ownership.

While an item is held:

- Disable its gameplay collision.
- Position its visual above the holding Ghost.
- Prevent other pickup requests.

Dropping returns the item to `WORLD`. Throwing clears `held_by_slot`, transitions it to `THROWN`, and updates its authoritative position and movement state. A completed throw that does not consume the item returns it to `WORLD`.

Item spawning remains active while any persistent Ghost is active. When the last Ghost deactivates, authoritatively despawn all `WORLD` items but allow existing `THROWN` items to finish. A thrown item can still affect a Player Character; if it misses and returns to `WORLD` after all Ghosts are inactive, despawn it immediately.

Before any normal return, forced swap, or other Ghost deactivation, the Host drops its `HELD` item into `WORLD` at the Ghost's current position and clears `held_by_slot`; the normal last-Ghost cleanup rule then applies.

If competing pickup requests target the same item, the first valid request processed by the Host wins. Reject later requests silently and let synchronized item state correct the losing peer.

## 9. Keep SignalBus Local

`Scripts/SignalBus.gd` should not become the network transport.

The Host mutates authoritative gameplay state. Use the following transport contract:

- Input intentions and discrete Joining Peer requests use validated RPCs.
- Durable gameplay facts use `MultiplayerSynchronizer` properties and `MultiplayerSpawner` nodes.
- One-shot presentation cues use reliable RPCs and never mutate gameplay state.
- Missing a presentation cue may reduce polish but can never change a Match outcome.

Each peer can then use local signals for presentation:

- HUD updates
- Sounds
- Screen effects
- Animations
- Music changes

This prevents gameplay signals such as `take_damage` from being applied twice or only on one machine.

## 10. Synchronize Match Flow

The Host must own and replicate:

- Match start
- Current wave
- Wave transitions
- Boss phase transitions
- Game over
- Victory
- Restart
- Return to menu
- Global pause state

The Host can pause the entire Match immediately. A Joining Peer opening its pause menu only opens a local, non-pausing overlay with Resume and Disconnect controls; it does not send a pause request. While that menu is open, send neutral movement for Player Slot 2 and display a clear warning that the Match is still running and the Player Character remains vulnerable.

Losing window focus never pauses the Match automatically. Focus loss immediately substitutes neutral input for the affected Player Slot when possible; in particular, Host focus loss neutralizes Player Slot 1 while authoritative simulation continues. The Host must pause deliberately when a global pause is wanted.

Starting, Restarting, or beginning a Rematch uses a two-peer loading barrier: both peers load the gameplay scene and explicitly report readiness, the Lobby displays “Waiting for other player…” as needed, and the Host starts simulation, timers, and waves only after both are ready. Either Participant may cancel while waiting. If the other Participant does not report readiness within 30 seconds, close the Session and return both sides to the main menu with “Other player failed to load.”

Restart or Rematch retains the existing Session and performs a Host-initiated synchronized scene reload. On victory or game over, the Host sees Restart/Rematch and Return to Main Menu controls. The Joining Peer sees “Waiting for Host…” and Disconnect and cannot request a restart.

Return to Main Menu closes the Session. If either peer disconnects during a Match, both sides end the Match, show the appropriate disconnect reason, return to the main menu, and close the Session.

Keep the networking autoload in `PROCESS_MODE_ALWAYS` so it can process connection events and RPCs while the scene tree is paused.

## 11. Make Lifecycle and Reset Explicit

Model Session lifecycle explicitly instead of inferring it from the current scene:

```gdscript
enum SessionState { IDLE, HOSTING, CONNECTING, LOBBY, LOADING, IN_MATCH, CLOSING }
enum MatchPhase { LOADING, PLAYING, PAUSED, GAME_OVER, VICTORY }
```

`NetworkSession` owns transport, peer assignment, protocol validation, Session state, and scene-readiness coordination. The authoritative Match controller owns Match phase, waves, game-over, victory, and global pause. Transitions must be validated and idempotent so duplicate Start, Restart, disconnect, or scene-ready messages cannot execute twice.

The Host increments a monotonic `match_generation` before every initial Match, Restart, or Rematch. Include it in every Match-scoped command, request, readiness message, and presentation event. Both sides reject messages for any other generation so delayed input or reliable RPCs from a previous scene cannot affect the new Match.

Session and Lobby RPC endpoints live on the stable `NetworkSession` autoload. Match-scoped RPC endpoints are used only after the two-peer loading barrier confirms that identical gameplay scene paths exist on both peers.

Before each Match generation, clear all Match-scoped state, including cached input, readiness flags, spawned-entity accounting, wave queues, Timed Item Effects, Ghost/item ownership, timers, tweens, and debug skip flags. On leaving or losing a Session, also close the multiplayer peer, clear peer-to-slot assignments and `Global` scene references, restore `get_tree().paused = false` and `Engine.time_scale = 1.0`, and return `NetworkSession` to `IDLE`. Repeated Host, Join, Restart, Rematch, and Local Co-op cycles must not accumulate signal connections or retain stale nodes and references.

## Security and Validation

The first version assumes a cooperative LAN environment. The Host accepts the first protocol-compatible Joining Peer; Session passwords, Participant authentication, and transport encryption are deferred. This does not weaken gameplay validation.

Every `@rpc("any_peer")` method must validate its sender.

Validate at least:

- The sender controls the requested Player Slot.
- Movement vectors have a maximum length of `1.0`.
- Sprinting is allowed by current stamina and status effects.
- Item interactions are within range.
- The requested item is in `WORLD` and not already held.
- Competing pickup requests follow Host processing order.
- Throw and pickup actions respect cooldowns and current state.
- The Joining Peer cannot request damage, enemy deaths, item outcomes, or wave changes.

Do not accept nodes, resources, or arbitrary object state from the Joining Peer.

## Implementation Order

1. Move health and Player Slot identity out of HUD/input-prefix code.
2. Separate local-dual and online input collection from simulation while making every mode use the same command-application path.
3. Add the explicit Session state machine, Match phase model, generation IDs, and reset contract.
4. Add the fixed-port ENet Host LAN Game / Join LAN Game Lobby, including protocol-version validation.
5. Add the two-peer scene-loading readiness barrier and assign each peer to one Player Slot.
6. Synchronize Player Character movement and state.
7. Make enemy AI, gameplay clocks, waves, damage, and random decisions Host-only.
8. Replicate enemies and one basic projectile with complete initial spawn state.
9. Activate and synchronize the two persistent Ghosts and sleeping state.
10. Replicate item spawning, pickup, drop, throw, and effects.
11. Replicate boss phases, victory, and game over.
12. Synchronize pause, restart, menu transitions, and full cleanup.
13. Tune interpolation and replication rates from profiling.

## Milestones

### Milestone 1: Connection

- The existing Local Co-op mode still starts without creating a Session.
- Host creates a LAN Session and sees its likely LAN IP address.
- Joining Peer manually connects over `127.0.0.1` or the Host's displayed LAN IP address using the fixed port.
- Incompatible protocol versions are rejected before entering the Lobby.
- Both peers enter the Lobby, load the same gameplay scene, report readiness, and start only after the loading barrier completes.
- Session state transitions and Match generations agree on both peers.
- Connection failures and disconnects are handled.

### Milestone 2: Player Character Movement

- Each peer controls exactly one Player Slot.
- Host simulates both Player Characters.
- Both peers see synchronized, interpolated movement.

### Milestone 3: Basic Combat

- Host spawns one enemy.
- Enemy AI only runs on the host.
- Projectiles, damage, enemy death, and health agree on both peers.

### Milestone 4: Core Cooperative Mechanic

- Sleeping and waking synchronize.
- Each Player Slot's persistent Ghost activates, moves, returns, and deactivates consistently.
- Ghosts can authoritatively pick up, drop, and throw items.
- Both-sleeping game over occurs only once on the host.

### Milestone 5: Full Match

- All waves synchronize.
- Item effects and Backfires synchronize.
- Boss phases and bomb damage synchronize.
- Victory, game over, pause, and restart work on both peers.

### Milestone 6: Session Lifecycle and Local Compatibility

- Restart and Rematch retain the existing Session.
- Return to Main Menu closes the Session.
- Any disconnect ends the Match and returns both sides to the main menu with a reason.
- Every Match and Session exit clears authoritative state, peer mappings, replicated entities, timers, global references, pause state, and signal connections.
- Local Co-op remains playable through the full game without creating a Session.

## Verification

Test in increasing order of complexity:

1. Two game processes on one computer using `127.0.0.1`.
2. Native desktop builds on two computers on the same LAN, including Windows-to-Linux interoperability and invalid IPv4 input.
3. Protocol-version mismatch rejection.
4. One peer loading or reloading much more slowly than the other, including readiness timeout and cancellation.
5. Artificial LAN latency of approximately 50–100 ms.
6. Packet loss and jitter.
7. Joining Peer disconnect during Lobby, gameplay, Ghost mode, and boss phase.
8. Host disconnect during the same states.
9. Restart and return-to-menu across repeated Matches.
10. Joining Peer pause menu, either peer losing window focus, and stale input timeout all produce neutral input while the Match continues without an automatic pause.
11. Host and Joining Peer receive their distinct victory and game-over controls.
12. Every item effect and Backfire on both Player Slots, including deterministic replacement, sleep countdown, pause freezing, and Match cleanup of Timed Item Effects.
13. Item cleanup when the last Ghost deactivates, including held and in-flight items.
14. Simultaneous pickup requests for the same item.
15. Both Player Characters sleeping at nearly the same time.
16. Boss phase transition and victory under latency, including the debug-build-only Host shortcut.
17. Delayed or duplicate input, readiness, Start, Restart, and presentation RPCs from the wrong Match generation.
18. Repeated Host → Match → Main Menu → Host and Join → Match → Rematch cycles without stale state, duplicate signals, or retained nodes.
19. Local Co-op, Host input, and Joining Peer input producing the same simulation outcomes from equivalent commands.
20. Authoritative timers and cooldowns agreeing through latency, global pause, scene reload, and Match cleanup.

The first development target should remain small: **the Host and Joining Peer enter one room, each controls one Player Slot, and both see the same Player Character movement**. Add enemies, projectiles, Ghosts, items, and waves only after that foundation is stable.
