# Multiplayer Implementation Plan

## Goal

Add Terraria-style host-and-join multiplayer to the existing two-player co-op game:

- One player hosts and also plays.
- One remote player joins.
- The host runs the authoritative game simulation.
- Both players see and interact with the same world.

## Initial Scope

The first version should intentionally support only:

- One host and one joining player
- Direct IP or LAN connection
- Both players connecting before the match starts
- Host-controlled pause, restart, waves, and scene changes
- Ending the match if either peer disconnects

The following should be deferred:

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
host_game(port)
join_game(address, port)
leave_game()
start_match()
```

Use Godot's `ENetMultiplayerPeer`:

```gdscript
extends Node

const DEFAULT_PORT := 7000

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func host_game(port := DEFAULT_PORT) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, 1) # One client plus the host
    if error == OK:
        multiplayer.multiplayer_peer = peer
    return error

func join_game(address: String, port := DEFAULT_PORT) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, port)
    if error == OK:
        multiplayer.multiplayer_peer = peer
    return error
```

Godot assigns peer ID `1` to the server. The joining player receives another peer ID.

Update `Scripts/main_menu.gd` and its scene with:

- Host button
- Join button
- IP-address field
- Connection status
- Host-only Start button after another player connects
- Connection failure and disconnection messages

ENet uses UDP. Direct internet hosting normally requires UDP port forwarding or UPnP. Steam lobby/relay support can be added later as a different transport option.

## 2. Assign Peers to the Existing Players

For the first version, keep the existing `Player1` and `Player2` nodes in `main.tscn`.

Assign control when the match starts:

```text
Player1.controlling_peer_id = 1
Player2.controlling_peer_id = joining_peer_id
```

Separate player identity from input bindings. `input_prefix` currently serves both purposes.

Introduce explicit identity fields:

```gdscript
var player_slot: int
var controlling_peer_id: int
```

Each machine should use generic local actions such as:

```text
move_left
move_right
move_up
move_down
sprint
interact
```

The host associates received input with its sender's peer ID.

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

Use unreliable ordered messages for continuous movement because newer input supersedes older input. Use reliable messages for discrete actions:

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

Interpolate remote positions to avoid visible snapping.

Derive animations and visual effects locally from synchronized state where possible. Avoid synchronizing individual animation frames every network update.

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
- Ghosts
- Items and bombs

Place replicated objects under a stable world node such as:

```text
Main/ReplicatedEntities
```

The host creates and removes these objects. Their scenes can contain `MultiplayerSynchronizer` nodes for position and gameplay state.

Synchronizing every projectile is acceptable for the first version because the game has relatively few entities. Optimize only after profiling.

## 7. Move Health Out of the HUD

`Scripts/Item/heart.gd` currently owns player health. Gameplay state should not live in presentation code.

Move health into `Scripts/Player/player.gd` or a dedicated player-state module:

```gdscript
var health := 5.0
var max_health := 5.0

func apply_damage(amount: float) -> void:
    health = clampf(health - amount, 0.0, max_health)
```

The host applies damage and healing. The heart HUD only observes and displays synchronized health.

Replace string identifiers such as `"p1_"` in damage and item signals with player slots, peer IDs, or direct authoritative player references.

## 8. Avoid Reparenting Held Items

`Scripts/Item/item.gd` currently reparents held items between the world and a ghost. Scene-tree reparenting is difficult to replicate reliably.

Keep items under the stable replicated world node and represent ownership explicitly:

```gdscript
var held_by_peer_id := 0
```

While an item is held:

- Disable its gameplay collision.
- Position its visual above the holding ghost.
- Prevent other pickup requests.

Dropping or throwing clears `held_by_peer_id` and updates its authoritative position and movement state.

## 9. Keep SignalBus Local

`Scripts/SignalBus.gd` should not become the network transport.

The host should mutate authoritative game state. `MultiplayerSynchronizer` or reliable RPCs carry that state or event to the other peer. Each peer can then use local signals for presentation:

- HUD updates
- Sounds
- Screen effects
- Animations
- Music changes

This prevents gameplay signals such as `take_damage` from being applied twice or only on one machine.

## 10. Synchronize Match Flow

The host must own and replicate:

- Match start
- Current wave
- Wave transitions
- Boss phase transitions
- Game over
- Victory
- Restart
- Return to menu
- Global pause state

A client opening its pause menu should not independently pause the host. For the initial version, only the host should pause or restart the match.

Keep the networking autoload in `PROCESS_MODE_ALWAYS` so it can process connection events and RPCs while the scene tree is paused.

## Security and Validation

Every `@rpc("any_peer")` method must validate its sender.

Validate at least:

- The sender controls the requested player.
- Movement vectors have a maximum length of `1.0`.
- Sprinting is allowed by current stamina and status effects.
- Item interactions are within range.
- The requested item is available and not already held.
- Throw and pickup actions respect cooldowns and current state.
- Clients cannot request damage, enemy deaths, item outcomes, or wave changes.

Do not accept nodes, resources, or arbitrary object state from a client.

## Implementation Order

1. Move health and player identity out of HUD/input-prefix code.
2. Separate local input collection from player simulation.
3. Add the ENet host/join lobby.
4. Assign each peer to one existing player.
5. Synchronize player movement and state.
6. Make enemy AI, waves, damage, and random decisions host-only.
7. Replicate enemies and one basic projectile.
8. Replicate sleeping and ghost mode.
9. Replicate item spawning, pickup, drop, throw, and effects.
10. Replicate boss phases, victory, and game over.
11. Synchronize pause, restart, and menu transitions.
12. Add interpolation and then client prediction if testing shows it is needed.

## Milestones

### Milestone 1: Connection

- Host creates a session.
- Client joins over `127.0.0.1` or LAN.
- Both peers load the same gameplay scene.
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
- Ghost movement synchronizes.
- Ghosts can authoritatively pick up, drop, and throw items.
- Both-sleeping game over occurs only once on the host.

### Milestone 5: Full Match

- All waves synchronize.
- Item effects and backfires synchronize.
- Boss phases and bomb damage synchronize.
- Victory, game over, pause, and restart work on both peers.

### Milestone 6: Internet Usability

After the direct-IP version is stable, choose one:

- Document manual UDP port forwarding.
- Add UPnP port mapping.
- Add a Steam lobby and relay transport.

## Verification

Test in increasing order of complexity:

1. Two game processes on one computer using `127.0.0.1`.
2. Two computers on the same LAN.
3. Artificial latency of approximately 50–100 ms.
4. Packet loss and jitter.
5. Client disconnect during lobby, gameplay, ghost mode, and boss phase.
6. Host disconnect during the same states.
7. Restart and return-to-menu across repeated matches.
8. Every item effect and backfire on both player slots.
9. Both players sleeping at nearly the same time.
10. Boss phase transition and victory under latency.

The first development target should remain small: **host and client enter one room, each controls one player, and both see the same movement**. Add enemies, projectiles, ghosts, items, and waves only after that foundation is stable.
