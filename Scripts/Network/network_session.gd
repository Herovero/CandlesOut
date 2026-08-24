extends Node

signal session_state_changed(state: SessionState)
signal status_changed(message: String)
signal lobby_changed(can_start: bool)
signal match_started(generation: int)
signal session_ended(reason: String)
signal local_focus_changed(has_focus: bool)

enum SessionState { IDLE, HOSTING, CONNECTING, LOBBY, LOADING, IN_MATCH, CLOSING }
enum MatchPhase { LOADING, PLAYING, PAUSED, GAME_OVER, VICTORY }
enum PlayMode { LOCAL_COOP, ONLINE_HOST, ONLINE_JOIN }

const LAN_PORT := 7000
const PROTOCOL_VERSION := 3
const HOST_PEER_ID := 1
const REPLICATION_INTERVAL := 1.0 / 30.0
const INTERPOLATION_SPEED := 18.0
const INTERPOLATION_SNAP_DISTANCE := 96.0
const PLAYFIELD_SCENE := "res://Scenes/main.tscn"
const MENU_SCENE := "res://Scenes/main_menu.tscn"
const CONNECTION_TIMEOUT_SECONDS := 10.0
const LOADING_TIMEOUT_SECONDS := 30.0

var session_state: SessionState = SessionState.IDLE
var match_phase: MatchPhase = MatchPhase.LOADING
var play_mode: PlayMode = PlayMode.LOCAL_COOP
var match_generation: int = 0
var joining_peer_id: int = 0
var host_lan_address: String = ""
var status_message: String = ""
var next_match_starts_at_boss: bool = false
var local_has_focus: bool = true
var local_input_suppressed: bool = false

var _connection_timeout_left: float = 0.0
var _loading_timeout_left: float = 0.0
var _ready_peers: Dictionary = {}
var _joining_peer_lobby_ready: bool = false
var _returning_to_menu: bool = false
var _audio_variant_seed: int = 0
var _current_music_wave: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_ensure_online_input_actions()


func _process(delta: float) -> void:
	if session_state == SessionState.CONNECTING and _connection_timeout_left > 0.0:
		_connection_timeout_left -= delta
		if _connection_timeout_left <= 0.0:
			_end_session("Connection timed out.", true)

	if session_state == SessionState.LOADING and multiplayer.is_server() and _loading_timeout_left > 0.0:
		_loading_timeout_left -= delta
		if _loading_timeout_left <= 0.0:
			_end_session("Other player failed to load.", true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		local_has_focus = false
		local_focus_changed.emit(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		local_has_focus = true
		local_focus_changed.emit(true)


func host_game() -> Error:
	leave_game(false)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(LAN_PORT, 1)
	if error != OK:
		_set_status("Could not host LAN game (error %d)." % error)
		return error

	multiplayer.multiplayer_peer = peer
	play_mode = PlayMode.ONLINE_HOST
	host_lan_address = get_likely_lan_address()
	_joining_peer_lobby_ready = false
	_set_state(SessionState.HOSTING)
	_set_status("Waiting for Joining Peer…")
	lobby_changed.emit(false)
	get_tree().call_deferred("change_scene_to_file", PLAYFIELD_SCENE)
	return OK


func join_game(address: String) -> Error:
	var normalized_address := address.strip_edges()
	if not is_valid_ipv4_address(normalized_address):
		_set_status("Enter a valid IPv4 address.")
		return ERR_INVALID_PARAMETER

	leave_game(false)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(normalized_address, LAN_PORT)
	if error != OK:
		_set_status("Could not connect (error %d)." % error)
		return error

	multiplayer.multiplayer_peer = peer
	play_mode = PlayMode.ONLINE_JOIN
	host_lan_address = normalized_address
	_connection_timeout_left = CONNECTION_TIMEOUT_SECONDS
	_set_state(SessionState.CONNECTING)
	_set_status("Connecting to %s:%d…" % [normalized_address, LAN_PORT])
	return OK


func start_local_match(start_at_boss: bool = false) -> void:
	leave_game(false)
	play_mode = PlayMode.LOCAL_COOP
	next_match_starts_at_boss = start_at_boss
	Global.skip_to_boss = start_at_boss
	get_tree().change_scene_to_file(PLAYFIELD_SCENE)


func start_match() -> Error:
	if not can_start_match():
		return ERR_UNAUTHORIZED

	match_generation += 1
	match_phase = MatchPhase.LOADING
	_ready_peers = {HOST_PEER_ID: false, joining_peer_id: false}
	_loading_timeout_left = LOADING_TIMEOUT_SECONDS
	_set_state(SessionState.LOADING)
	_set_status("Loading match…")
	_load_match.rpc(match_generation, PLAYFIELD_SCENE, next_match_starts_at_boss)
	return OK


func restart_match() -> Error:
	if not is_online():
		GameplayAudio.reset()
		Global.skip_to_boss = false
		return get_tree().reload_current_scene()
	if not is_online_host() or session_state != SessionState.IN_MATCH:
		return ERR_UNAUTHORIZED
	return start_match_from_session()


func start_match_from_session() -> Error:
	if not is_online_host() or joining_peer_id == 0:
		return ERR_UNAUTHORIZED
	match_generation += 1
	match_phase = MatchPhase.LOADING
	_ready_peers = {HOST_PEER_ID: false, joining_peer_id: false}
	_loading_timeout_left = LOADING_TIMEOUT_SECONDS
	_set_state(SessionState.LOADING)
	_set_status("Loading match…")
	_load_match.rpc(match_generation, PLAYFIELD_SCENE, false)
	return OK


func leave_game(return_to_menu: bool = false, reason: String = "") -> void:
	_set_state(SessionState.CLOSING)
	GameplayAudio.reset()
	get_tree().paused = false
	Engine.time_scale = 1.0
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	joining_peer_id = 0
	host_lan_address = ""
	_ready_peers.clear()
	_joining_peer_lobby_ready = false
	_connection_timeout_left = 0.0
	_loading_timeout_left = 0.0
	match_phase = MatchPhase.LOADING
	play_mode = PlayMode.LOCAL_COOP
	next_match_starts_at_boss = false
	local_input_suppressed = false
	Global.skip_to_boss = false
	Global.wave = null
	Global.spawners.clear()
	Global.item_spawner = null
	Global.ost_manager = null
	Global.active_footstep_count = 0
	_audio_variant_seed = 0
	_current_music_wave = 0
	_set_state(SessionState.IDLE)
	lobby_changed.emit(false)
	if not reason.is_empty():
		_set_status(reason)
		session_ended.emit(reason)
	if return_to_menu:
		_return_to_menu()


func scene_ready(generation: int) -> void:
	if not is_online() or session_state != SessionState.LOADING or generation != match_generation:
		return
	if multiplayer.is_server():
		_mark_peer_ready(HOST_PEER_ID, generation)
	else:
		_report_scene_ready.rpc_id(HOST_PEER_ID, generation)


func lobby_scene_ready() -> void:
	if not is_joining_peer() or session_state != SessionState.LOBBY:
		return
	_set_status("In the Lobby. Waiting for Host to start the Match…")
	_report_lobby_ready.rpc_id(HOST_PEER_ID, match_generation)


func is_in_lobby() -> bool:
	return is_online() and session_state in [SessionState.HOSTING, SessionState.LOBBY]


func can_start_match() -> bool:
	return is_online_host() \
		and session_state == SessionState.LOBBY \
		and joining_peer_id != 0 \
		and _joining_peer_lobby_ready


func is_online() -> bool:
	return play_mode != PlayMode.LOCAL_COOP


func is_online_host() -> bool:
	return play_mode == PlayMode.ONLINE_HOST


func is_joining_peer() -> bool:
	return play_mode == PlayMode.ONLINE_JOIN


func has_simulation_authority() -> bool:
	return not is_online() or multiplayer.is_server()


func get_peer_for_slot(player_slot: int) -> int:
	if not is_online():
		return HOST_PEER_ID
	return HOST_PEER_ID if player_slot == 1 else joining_peer_id


func get_local_player_slot() -> int:
	return 2 if is_joining_peer() else 1


func get_replicated_entities() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("ReplicatedEntities")


func spawn_replicated(scene: PackedScene, properties: Dictionary = {}) -> Node:
	if not has_simulation_authority() or scene == null:
		return null
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_method("spawn_replicated"):
		return current_scene.spawn_replicated(scene.resource_path, properties)

	var instance := scene.instantiate()
	_apply_properties(instance, properties)
	var root := get_replicated_entities()
	if root == null:
		root = current_scene
	root.add_child(instance)
	return instance


func configure_synchronizer(root: Node, properties: Array[StringName], interval: float = REPLICATION_INTERVAL) -> void:
	if not is_online():
		return
	var synchronizer := root.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if synchronizer == null:
		synchronizer = MultiplayerSynchronizer.new()
		synchronizer.name = "MultiplayerSynchronizer"
		synchronizer.root_path = NodePath("..")
		synchronizer.replication_interval = interval
		synchronizer.replication_config = SceneReplicationConfig.new()
		if multiplayer.is_server() and is_in_lobby():
			synchronizer.public_visibility = _joining_peer_lobby_ready
		root.add_child(synchronizer)
	var config := synchronizer.replication_config
	for property in properties:
		var path := NodePath(".:%s" % property)
		if config.has_property(path):
			continue
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_sync(path, true)


func _set_lobby_replication_enabled(enabled: bool) -> void:
	if not multiplayer.is_server():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node in scene.find_children("*", "MultiplayerSynchronizer", true, false):
		(node as MultiplayerSynchronizer).public_visibility = enabled


func configure_moving_synchronizer(root: Node, properties: Array[StringName] = []) -> void:
	var moving_properties: Array[StringName] = [
		&"network_generation", &"network_position", &"network_velocity",
	]
	moving_properties.append_array(properties)
	configure_synchronizer(root, moving_properties, REPLICATION_INTERVAL)


func publish_movement(root: Node2D, movement_velocity: Vector2 = Vector2.ZERO) -> void:
	root.set(&"network_generation", match_generation)
	root.set(&"network_position", root.position)
	root.set(&"network_velocity", movement_velocity)


func interpolate_movement(root: Node2D, delta: float, force_snap: bool = false) -> void:
	if int(root.get(&"network_generation")) != match_generation:
		return
	var target: Vector2 = root.get(&"network_position")
	if force_snap or root.position.distance_to(target) >= INTERPOLATION_SNAP_DISTANCE:
		root.position = target
		return
	var weight := 1.0 - exp(-INTERPOLATION_SPEED * delta)
	root.position = root.position.lerp(target, weight)


func broadcast_sfx(cue: int, world_position: Vector2, variant_seed: int = -1) -> void:
	if variant_seed < 0:
		_audio_variant_seed += 1
		variant_seed = _audio_variant_seed
	if not is_online():
		GameplayAudio.play_sfx(cue, world_position, variant_seed)
	elif is_online_host() and session_state == SessionState.IN_MATCH:
		_receive_sfx.rpc(match_generation, cue, world_position, variant_seed)


func broadcast_music(wave_number: int) -> void:
	if not is_online():
		_current_music_wave = wave_number
		GameplayAudio.play_wave_music(wave_number)
	elif is_online_host() and session_state == SessionState.IN_MATCH:
		_receive_music_state.rpc(match_generation, wave_number)


func broadcast_music_stop() -> void:
	if not is_online():
		_current_music_wave = 0
		GameplayAudio.stop_music()
	elif is_online_host():
		_receive_music_stop.rpc(match_generation)


func get_likely_lan_address() -> String:
	for interface: Dictionary in IP.get_local_interfaces():
		var name := str(interface.get("name", "")).to_lower()
		var friendly := str(interface.get("friendly", "")).to_lower()
		if not _is_wifi_or_ethernet(name, friendly):
			continue

		for address_value: Variant in interface.get("addresses", []):
			var address := str(address_value)
			if is_valid_ipv4_address(address) and _is_private_ipv4(address):
				return address

	return "127.0.0.1"


func _is_wifi_or_ethernet(name: String, friendly: String) -> bool:
	if friendly.begins_with("wi-fi") or friendly.begins_with("wireless"):
		return true
	if friendly.begins_with("ethernet"):
		return true
	return name.begins_with("wl") or name.begins_with("eth") or name.begins_with("en")


func _is_private_ipv4(address: String) -> bool:
	var parts := address.split(".", false)
	var first := int(parts[0])
	var second := int(parts[1])
	return first == 10 or (first == 172 and second >= 16 and second <= 31) or (first == 192 and second == 168)


func is_valid_ipv4_address(address: String) -> bool:
	var parts := address.split(".", false)
	if parts.size() != 4:
		return false
	for part in parts:
		if part.is_empty() or not part.is_valid_int():
			return false
		if part.length() > 1 and part.begins_with("0"):
			return false
		var value := int(part)
		if value < 0 or value > 255:
			return false
	return true


@rpc("authority", "call_local", "unreliable", 2)
func _receive_sfx(generation: int, cue: int, world_position: Vector2, variant_seed: int) -> void:
	if generation != match_generation or session_state != SessionState.IN_MATCH:
		return
	GameplayAudio.play_sfx(cue, world_position, variant_seed)


@rpc("authority", "call_local", "reliable")
func _receive_music_state(generation: int, wave_number: int) -> void:
	if generation != match_generation or session_state != SessionState.IN_MATCH:
		return
	_current_music_wave = wave_number
	GameplayAudio.play_wave_music(wave_number)


@rpc("authority", "call_local", "reliable")
func _receive_music_stop(generation: int) -> void:
	if generation != match_generation:
		return
	_current_music_wave = 0
	GameplayAudio.stop_music()


@rpc("any_peer", "call_remote", "reliable")
func _register_protocol(version: int) -> void:
	if not multiplayer.is_server() or session_state not in [SessionState.HOSTING, SessionState.LOBBY]:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= HOST_PEER_ID:
		return
	if joining_peer_id != 0 and joining_peer_id != sender:
		_protocol_rejected.rpc_id(sender, "Session is full.")
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	if version != PROTOCOL_VERSION:
		_protocol_rejected.rpc_id(sender, "Game versions do not match.")
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return

	joining_peer_id = sender
	_joining_peer_lobby_ready = false
	_set_state(SessionState.LOBBY)
	_set_status("Player connected. Waiting for them to enter the Lobby…")
	lobby_changed.emit(false)
	_protocol_accepted.rpc_id(sender, match_generation)


@rpc("authority", "call_remote", "reliable")
func _protocol_accepted(server_generation: int) -> void:
	if not is_joining_peer() or session_state != SessionState.CONNECTING:
		return
	_connection_timeout_left = 0.0
	match_generation = server_generation
	joining_peer_id = multiplayer.get_unique_id()
	_set_state(SessionState.LOBBY)
	_set_status("Connected. Entering the Lobby…")
	lobby_changed.emit(false)
	get_tree().call_deferred("change_scene_to_file", PLAYFIELD_SCENE)


@rpc("authority", "call_remote", "reliable")
func _protocol_rejected(reason: String) -> void:
	if not is_joining_peer():
		return
	_end_session(reason, true)


@rpc("authority", "call_local", "reliable")
func _load_match(generation: int, scene_path: String, start_at_boss: bool) -> void:
	if not is_online() or generation < match_generation or scene_path != PLAYFIELD_SCENE:
		return
	GameplayAudio.reset()
	_audio_variant_seed = 0
	_current_music_wave = 0
	match_generation = generation
	match_phase = MatchPhase.LOADING
	Global.skip_to_boss = start_at_boss
	_set_state(SessionState.LOADING)
	_set_status("Loading match…")
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", scene_path)


@rpc("any_peer", "call_remote", "reliable")
func _report_lobby_ready(generation: int) -> void:
	if not multiplayer.is_server() or session_state != SessionState.LOBBY or generation != match_generation:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != joining_peer_id:
		return
	_joining_peer_lobby_ready = true
	_set_lobby_replication_enabled(true)
	_set_status("Both Participants are in the Lobby. Ready to start.")
	lobby_changed.emit(true)


@rpc("any_peer", "call_remote", "reliable")
func _report_scene_ready(generation: int) -> void:
	if not multiplayer.is_server() or session_state != SessionState.LOADING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != joining_peer_id:
		return
	_mark_peer_ready(sender, generation)


@rpc("authority", "call_local", "reliable")
func _confirm_match_started(generation: int) -> void:
	if not is_online() or session_state != SessionState.LOADING or generation != match_generation:
		return
	_loading_timeout_left = 0.0
	match_phase = MatchPhase.PLAYING
	_set_state(SessionState.IN_MATCH)
	_set_status("")
	get_tree().paused = false
	match_started.emit(generation)


func _mark_peer_ready(peer_id: int, generation: int) -> void:
	if not multiplayer.is_server() or generation != match_generation or not _ready_peers.has(peer_id):
		return
	_ready_peers[peer_id] = true
	if _ready_peers.values().all(func(value: Variant) -> bool: return value == true):
		_confirm_match_started.rpc(match_generation)
	else:
		_set_status("Waiting for other player…")


func _on_connected_to_server() -> void:
	if not is_joining_peer() or session_state != SessionState.CONNECTING:
		return
	_set_status("Connected. Checking game version…")
	_register_protocol.rpc_id(HOST_PEER_ID, PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	if session_state == SessionState.CONNECTING:
		_end_session("Connection failed.", true)


func _on_server_disconnected() -> void:
	if is_joining_peer():
		_end_session("Host disconnected.", true)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server() and session_state == SessionState.HOSTING:
		_set_status("Player connected. Checking game version…")
	elif not multiplayer.is_server() and joining_peer_id == 0:
		joining_peer_id = multiplayer.get_unique_id()


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_online() or peer_id != joining_peer_id:
		return
	if session_state in [SessionState.LOADING, SessionState.IN_MATCH]:
		_end_session("Other player disconnected.", true)
	elif multiplayer.is_server():
		joining_peer_id = 0
		_joining_peer_lobby_ready = false
		_set_state(SessionState.HOSTING)
		_set_lobby_replication_enabled(false)
		_set_status("Player disconnected. Waiting for player…")
		lobby_changed.emit(false)


func _end_session(reason: String, return_to_menu: bool) -> void:
	leave_game(return_to_menu, reason)


func _return_to_menu() -> void:
	if _returning_to_menu:
		return
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == MENU_SCENE:
		return
	_returning_to_menu = true
	get_tree().call_deferred("change_scene_to_file", MENU_SCENE)
	get_tree().create_timer(0.1, true).timeout.connect(func() -> void: _returning_to_menu = false)


func _set_state(value: SessionState) -> void:
	if session_state == value:
		return
	session_state = value
	session_state_changed.emit(value)


func _set_status(message: String) -> void:
	status_message = message
	status_changed.emit(message)


func _apply_properties(node: Node, properties: Dictionary) -> void:
	for property in properties:
		if property in node:
			node.set(property, properties[property])


func _ensure_online_input_actions() -> void:
	var mappings := {
		"move_left": ["p1_move_left", "p2_move_left"],
		"move_right": ["p1_move_right", "p2_move_right"],
		"move_up": ["p1_move_up", "p2_move_up"],
		"move_down": ["p1_move_down", "p2_move_down"],
		"sprint": ["p1_sprint", "p2_sprint"],
		"interact": ["item_pickup&throw"],
	}
	for action in mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for source_action: String in mappings[action]:
			for event in InputMap.action_get_events(source_action):
				if not InputMap.action_has_event(action, event):
					InputMap.action_add_event(action, event)
