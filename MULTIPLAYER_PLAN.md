# Multiplayer Implementation Plan

## Goal

Add Terraria-style host-and-join multiplayer to the existing two-player co-op game without removing local co-op:

- Local Co-op continues to support two players on one machine.
- Online Co-op runs between two native desktop builds on the same LAN.
- One player hosts and also plays.
- One remote player joins.
- The host runs the authoritative game simulation.
- Both players see and interact with the same world.

## Initial Scope

The first version should intentionally support only:

- Native Windows and Linux desktop builds, including cross-platform LAN Sessions
- IPv4 LAN addresses only
- Local Co-op with both players on one machine
- Online Co-op with one host and one joining player on the same LAN
- Joining by entering the host's LAN IP address
- Both players connecting before the match starts
- Host-controlled pause, restart, waves, and scene changes
- Ending the match if either peer disconnects

The following are out of scope:

- Internet multiplayer, NAT traversal, port forwarding, or UPnP
- Session passwords, authentication, or transport encryption
- Automatic LAN host discovery
- Web multiplayer
- Joining a match already in progress
- Reconnection and host migration
- More than two players
- Steam lobbies and relay networking
- Full client-side prediction

## Authority Model

Use a **host-authoritative simulation**. The joining player sends input intentions to the host, and the host decides the resulting game state.

| State | Authority |
|---|---|
| Player movement and stamina | Host |
| Health and damage | Host |
| Enemy AI and health | Host |
| Projectiles and collisions | Host |
| Ghost creation and movement | Host |
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
- Host-only Start button after another player connects
- Connection failure and disconnection messages

Do not implement automatic LAN discovery in the first version. The existing Boss button is a development shortcut, not a player-facing mode; hide it in release builds. In debug builds only, expose a clearly marked `Debug: Host Boss Match` control that can start Local Co-op at the boss or configure the Host's next Online Co-op Match to start there.

ENet uses UDP. This plan only supports peers that can reach each other on the same LAN; internet discovery, NAT traversal, and relay transports are intentionally excluded.

## 2. Assign Peers to the Existing Players

For the first version, keep the existing `Player1` and `Player2` nodes in `main.tscn`.

For Online Co-op, assign control when the match starts:

```text
Player1.controlling_peer_id = 1
Player2.controlling_peer_id = joining_peer_id
```

The Host always occupies Player Slot 1 and the Joining Peer always occupies Player Slot 2. Local Co-op keeps both slots on one machine.

Player Slot is the exclusive gameplay identity for health, damage, item and ghost ownership, effects, and HUD targeting. Peer IDs are transport identities used only to authorize which Online Co-op participant may submit input for a Player Slot.

Separate player identity from input bindings. `input_prefix` currently serves both purposes.

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

Bind that generic action set to the local keyboard and controller device `0`, allowing either device to control the machine's one Online Co-op participant. The host associates received input with its sender's peer ID.

Preserve the existing two keyboard layouts and controller assignments for Local Co-op behind a separate local-dual-input adapter so player simulation does not need to know which mode supplied a command.

## 3. Separate Input Collection from Simulation

`Scripts/Player/player.gd` currently reads `Input` and immediately updates the body. Split those responsibilities behind functions such as:

```gdscript
func sample_local_input() -> PlayerCommand
func apply_command(command: PlayerCommand, delta: float) -> void
```

The joining player sends movement intentions to the host:

```gdscript
submit_input.rpc_id(1, direction, sprinting)
```

The host validates the sender and stores the latest input:

```gdscript
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(direction: Vector2, sprinting: bool) -> void:
    if not multiplayer.is_server():
        return

    var sender := multiplayer.get_remote_sender_id()
    if sender != controlling_peer_id:
        return

    latest_direction = direction.limit_length(1.0)
    latest_sprinting = sprinting
```

Use unreliable ordered messages for continuous movement because newer input supersedes older input. The Joining Peer sends input continuously at an initial rate of 30 Hz, even when unchanged. If the Host receives no input update for 500 ms, it substitutes neutral movement and disables sprint until fresh input arrives. Losing window focus should immediately send neutral input when possible.

Use reliable messages for discrete actions:

- Pick up item
- Drop item
- Throw item
- Pause
- Restart
- Return to menu

Initially, accept the input delay caused by waiting for the host. Add client prediction and reconciliation later if remote movement—especially ghost movement—feels sluggish.

## 4. Synchronize Player State

Add a `MultiplayerSynchronizer` to each player.

Synchronize authoritative properties including:

- Position and velocity
- Health
- Stamina
- Sleeping and returning states
- Invincibility and status effects
- Active ghost state
- Animation-relevant state

Run authoritative physics at 60 Hz, initially synchronize moving transforms at 20 Hz, and interpolate remote positions to avoid visible snapping. Keep input and synchronization rates as named developer constants rather than player-facing settings, and adjust them only after profiling.

Give each Player Slot one persistent ghost node with a stable scene path. While its player is awake, the ghost is inactive, invisible, and non-colliding. The Host activates and positions it when the player sleeps, synchronizes its movement and state, then deactivates it after the return animation. Do not dynamically spawn or destroy ghosts.

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

Do not allow clients to run independent enemy AI, damage checks, spawning, or wave progression.

Split authoritative simulation from visual presentation rather than disabling entire scripts on clients. Clients still need to render animations, particles, sounds, and interpolated movement.

All random decisions must occur on the host, including:

- Wave queue shuffling
- Weighted item selection
- Item backfire outcomes
- Bomb behavior
- Boss attack selection
- Random spawn positions

## 6. Replicate Dynamic Objects

Use `MultiplayerSpawner` for dynamically created objects:

- Enemies
- Projectiles
- Items and bombs

Place replicated objects under a stable world node such as:

```text
Main/ReplicatedEntities
```

The Host creates and removes these objects. Their scenes can contain `MultiplayerSynchronizer` nodes for position and gameplay state. Commit to Godot's `MultiplayerSpawner` and `MultiplayerSynchronizer` for the first version rather than building a custom snapshot or entity-replication protocol.

Synchronizing every projectile is acceptable for the first version because the game has relatively few entities. Optimize only after profiling.

## 7. Move Health Out of the HUD

`Scripts/Item/heart.gd` currently owns player health. Gameplay state should not live in presentation code.

Move health directly into `Scripts/Player/player.gd`, alongside stamina, sleeping, and status effects:

```gdscript
var health := 5.0
var max_health := 5.0

func apply_damage(amount: float) -> void:
    health = clampf(health - amount, 0.0, max_health)
```

The Host applies damage and healing. The heart HUD only observes and displays synchronized health.

Each Player Slot can have at most one Timed Item Effect. Applying a new Timed Item Effect first performs complete authoritative cleanup of the previous one, then applies the new effect and duration. Timed Item Effects continue counting down while a player sleeps or controls a ghost, freeze during global Host pause, and clear when the Match ends or restarts. Hit stun, damage invincibility, knockback, sleeping, and ghost transitions are intrinsic player states rather than Timed Item Effects and do not participate in this replacement rule.

Replace string identifiers such as `"p1_"` in damage and item signals with Player Slots. Do not use peer IDs as gameplay targets.

## 8. Avoid Reparenting Held Items

`Scripts/Item/item.gd` currently reparents held items between the world and a ghost. Scene-tree reparenting is difficult to replicate reliably.

Keep items under the stable replicated world node and represent their authoritative lifecycle explicitly:

```gdscript
enum ItemState { WORLD, HELD, THROWN }
var item_state := ItemState.WORLD
var held_by_slot := 0
```

`WORLD` items are available for pickup, `HELD` items logically follow a Player Slot's active ghost, and `THROWN` items move through the world. Consumption or cleanup removes the item through authoritative replicated despawning; scene-tree parentage never represents gameplay ownership.

While an item is held:

- Disable its gameplay collision.
- Position its visual above the holding ghost.
- Prevent other pickup requests.

Dropping returns the item to `WORLD`. Throwing clears `held_by_slot`, transitions it to `THROWN`, and updates its authoritative position and movement state. A completed throw that does not consume the item returns it to `WORLD`.

Item spawning remains active while any persistent ghost is active. When the last ghost deactivates, authoritatively despawn all `WORLD` items but allow existing `THROWN` items to finish. A thrown item can still affect a player; if it misses and returns to `WORLD` after all ghosts are inactive, despawn it immediately.

Before any normal return, forced swap, or other ghost deactivation, the Host drops its `HELD` item into `WORLD` at the ghost's current position and clears `held_by_slot`; the normal last-ghost cleanup rule then applies.

If competing pickup requests target the same item, the first valid request processed by the Host wins. Reject later requests silently and let synchronized item state correct the losing peer.

## 9. Keep SignalBus Local

`Scripts/SignalBus.gd` should not become the network transport.

The Host mutates authoritative gameplay state. Use the following transport contract:

- Input intentions and discrete client requests use validated RPCs.
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

The Host can pause the entire Match immediately. A Joining Peer opening its pause menu only opens a local, non-pausing overlay with Resume and Disconnect controls; it does not send a pause request. While that menu is open, send neutral movement for Player Slot 2 and display a clear warning that the Match is still running and the character remains vulnerable.

Losing window focus never pauses the Match automatically. Focus loss immediately substitutes neutral input for the affected Player Slot when possible; in particular, Host focus loss neutralizes Player Slot 1 while authoritative simulation continues. The Host must pause deliberately when a global pause is wanted.

Starting, Restarting, or beginning a Rematch uses a two-peer loading barrier: both peers load the gameplay scene and explicitly report readiness, the Lobby displays “Waiting for other player…” as needed, and the Host starts simulation, timers, and waves only after both are ready. Either participant may cancel while waiting. If the other participant does not report readiness within 30 seconds, close the Session and return both sides to the main menu with “Other player failed to load.”

Restart or Rematch retains the existing Session and performs a Host-initiated synchronized scene reload. On victory or game over, the Host sees Restart/Rematch and Return to Main Menu controls. The Joining Peer sees “Waiting for Host…” and Disconnect and cannot request a restart.

Return to Main Menu closes the Session. If either peer disconnects during a Match, both sides end the Match, show the appropriate disconnect reason, return to the main menu, and close the Session.

Keep the networking autoload in `PROCESS_MODE_ALWAYS` so it can process connection events and RPCs while the scene tree is paused.

## Security and Validation

The first version assumes a cooperative LAN environment. The Host accepts the first protocol-compatible Joining Peer; Session passwords, participant authentication, and transport encryption are deferred. This does not weaken gameplay validation.

Every `@rpc("any_peer")` method must validate its sender.

Validate at least:

- The sender controls the requested player.
- Movement vectors have a maximum length of `1.0`.
- Sprinting is allowed by current stamina and status effects.
- Item interactions are within range.
- The requested item is in `WORLD` and not already held.
- Competing pickup requests follow Host processing order.
- Throw and pickup actions respect cooldowns and current state.
- Clients cannot request damage, enemy deaths, item outcomes, or wave changes.

Do not accept nodes, resources, or arbitrary object state from a client.

## Implementation Order

1. Move health and player identity out of HUD/input-prefix code.
2. Separate local-dual and online input collection from player simulation while preserving Local Co-op.
3. Add the fixed-port ENet Host LAN Game / Join LAN Game Lobby, including protocol-version validation.
4. Add the two-peer scene-loading readiness barrier and assign each peer to one existing player.
5. Synchronize player movement and state.
6. Make enemy AI, waves, damage, and random decisions host-only.
7. Replicate enemies and one basic projectile.
8. Activate and synchronize the two persistent ghosts and sleeping state.
9. Replicate item spawning, pickup, drop, throw, and effects.
10. Replicate boss phases, victory, and game over.
11. Synchronize pause, restart, and menu transitions.
12. Add interpolation and then client prediction if testing shows it is needed.

## Milestones

### Milestone 1: Connection

- The existing Local Co-op mode still starts without creating a Session.
- Host creates a LAN Session and sees its likely LAN IP address.
- Joining Peer manually connects over `127.0.0.1` or the Host's displayed LAN IP address using the fixed port.
- Incompatible protocol versions are rejected before entering the Lobby.
- Both peers enter the Lobby, load the same gameplay scene, report readiness, and start only after the loading barrier completes.
- Connection failures and disconnects are handled.

### Milestone 2: Player Movement

- Each peer controls exactly one player.
- Host simulates both players.
- Both peers see synchronized, interpolated movement.

### Milestone 3: Basic Combat

- Host spawns one enemy.
- Enemy AI only runs on the host.
- Projectiles, damage, enemy death, and health agree on both peers.

### Milestone 4: Core Cooperative Mechanic

- Sleeping and waking synchronize.
- Each Player Slot's persistent ghost activates, moves, returns, and deactivates consistently.
- Ghosts can authoritatively pick up, drop, and throw items.
- Both-sleeping game over occurs only once on the host.

### Milestone 5: Full Match

- All waves synchronize.
- Item effects and backfires synchronize.
- Boss phases and bomb damage synchronize.
- Victory, game over, pause, and restart work on both peers.

### Milestone 6: Session Lifecycle and Local Compatibility

- Restart and Rematch retain the existing Session.
- Return to Main Menu closes the Session.
- Any disconnect ends the Match and returns both sides to the main menu with a reason.
- Local Co-op remains playable through the full game without creating a Session.

## Verification

Test in increasing order of complexity:

1. Two game processes on one computer using `127.0.0.1`.
2. Native desktop builds on two computers on the same LAN, including Windows-to-Linux interoperability and invalid IPv4 input.
3. Protocol-version mismatch rejection.
4. One peer loading or reloading much more slowly than the other, including readiness timeout and cancellation.
5. Artificial LAN latency of approximately 50–100 ms.
6. Packet loss and jitter.
7. Joining Peer disconnect during Lobby, gameplay, ghost mode, and boss phase.
8. Host disconnect during the same states.
9. Restart and return-to-menu across repeated Matches.
10. Joining Peer pause menu, either peer losing window focus, and stale input timeout all produce neutral input while the Match continues without an automatic pause.
11. Host and Joining Peer receive their distinct victory and game-over controls.
12. Every item effect and backfire on both Player Slots, including deterministic replacement, sleep countdown, pause freezing, and Match cleanup of Timed Item Effects.
13. Item cleanup when the last ghost deactivates, including held and in-flight items.
14. Simultaneous pickup requests for the same item.
15. Both players sleeping at nearly the same time.
16. Boss phase transition and victory under latency, including the debug-build-only Host shortcut.

The first development target should remain small: **host and client enter one room, each controls one player, and both see the same movement**. Add enemies, projectiles, ghosts, items, and waves only after that foundation is stable.
