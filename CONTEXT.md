# CandlesOut

CandlesOut is a two-player cooperative survival game. This glossary distinguishes gameplay identity, local control, and network participation.

## Language

**Session**:
The LAN-hosting lifecycle that begins when a Host starts waiting or a Joining Peer connects. It can contain a Lobby and consecutive Matches and ends when either Participant returns to the main menu or disconnects.
_Avoid_: Match, Lobby, game

**Lobby**:
The pre-Match state where the Host waits for the Joining Peer to connect and, once connected, controls when the Match starts.
_Avoid_: Session, main menu, Match

**Participant**:
A person controlling one Player Slot. Local Co-op Participants share a machine; Online Co-op Participants are the Host and Joining Peer.
_Avoid_: Peer, Player Slot, Player Character

**Host**:
The Session Participant who also plays and has final authority over shared Match outcomes.
_Avoid_: Server, Player 1

**Joining Peer**:
The remote Session Participant who joins the Host and controls Player Slot 2.
_Avoid_: Client player, guest, Player 2

**Match**:
One cooperative playthrough from gameplay start until victory, game over, disconnection, or return to the main menu.
_Avoid_: Session, lobby

**Player Slot**:
A stable gameplay identity, either 1 or 2, independent of network identity and input bindings. Health, effects, and ownership always target a Player Slot.
_Avoid_: Participant, Peer ID, input prefix

**Player Character**:
The candle body associated with one Player Slot. It moves and fights while awake and remains in place while its Ghost is active.
_Avoid_: Participant, Player Slot, player node

**Ghost**:
The controllable spirit associated with one Player Slot while its Player Character sleeps. It retrieves, carries, drops, and throws items.
_Avoid_: Player Character, Joining Peer

**Intrinsic Player State**:
A condition arising from core Player Character mechanics rather than an item. It can coexist with a Timed Item Effect.
_Avoid_: Timed Item Effect, item buff

**Timed Item Effect**:
A temporary item-caused modifier applied to a Player Slot. A Player Slot can have only one at a time, and a new Timed Item Effect replaces the previous one.
_Avoid_: Intrinsic Player State, item buff

**Backfire**:
An item's chaotic alternate outcome instead of its normal beneficial effect.
_Avoid_: Intrinsic Player State, ordinary damage

**Local Co-op**:
A mode in which one machine controls both Player Slots without a Session.
_Avoid_: Offline multiplayer, couch mode

**Online Co-op**:
A desktop LAN mode in which the Host controls Player Slot 1 and the Joining Peer controls Player Slot 2 within a Session.
_Avoid_: Internet multiplayer, network mode
