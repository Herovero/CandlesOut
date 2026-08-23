# CandlesOut

CandlesOut is a two-player cooperative survival game. This glossary distinguishes gameplay identity, local control, and network participation.

## Language

**Session**:
The LAN-hosting lifecycle that begins when a Host starts waiting or a Joining Peer connects. It can contain a Lobby and consecutive Matches and ends when either participant returns to the main menu or disconnects.
_Avoid_: Match, Lobby, game

**Lobby**:
The pre-Match state where the Host waits for the Joining Peer to connect and, once connected, controls when the Match starts.
_Avoid_: Session, main menu, Match

**Host**:
The Session participant who also plays and has final authority over shared Match outcomes.
_Avoid_: Server, Player 1

**Joining Peer**:
The remote Session participant who joins the Host and controls Player Slot 2.
_Avoid_: Client player, guest, Player 2

**Match**:
One cooperative playthrough from gameplay start until victory, game over, disconnection, or return to the main menu.
_Avoid_: Session, lobby

**Player Slot**:
A stable gameplay identity, either 1 or 2, independent of network identity and input bindings. Health, effects, and ownership always target a Player Slot.
_Avoid_: Peer ID, input prefix

**Timed Item Effect**:
A temporary item-caused modifier applied to a Player Slot. A Player Slot can have only one at a time, and a new Timed Item Effect replaces the previous one.
_Avoid_: Intrinsic player state, item buff

**Local Co-op**:
A mode in which one machine controls both Player Slots without a Session.
_Avoid_: Offline multiplayer, couch mode

**Online Co-op**:
A desktop LAN mode in which the Host controls Player Slot 1 and the Joining Peer controls Player Slot 2 within a Session.
_Avoid_: Internet multiplayer, network mode
