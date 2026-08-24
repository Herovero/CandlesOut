extends Node

enum Cue {
	PLAYER_SHOOT,
	PLAYER_BLOCK,
	PLAYER_SLEEP,
	ENEMY_SHOOT,
	ENEMY_ATTACK,
	ENEMY_DEATH,
	BOSS_CHARGE,
	BOSS_SLASH,
	BOSS_RADIAL,
	ITEM_HEART,
	ITEM_COFFEE,
	ITEM_LIGHTER,
	ITEM_OIL_GOOD,
	ITEM_OIL_BAD,
	ITEM_SHIELD,
	ITEM_SHOE,
	ITEM_SHOE_FAST,
	BOMB_EXPLOSION,
	BOMB_FLY,
}

const CUE_STREAMS := {
	Cue.PLAYER_SHOOT: [preload("res://SFX/Player/Fireball.wav")],
	Cue.PLAYER_BLOCK: [preload("res://SFX/Player/Blocked_bullet.wav")],
	Cue.PLAYER_SLEEP:
	[
		preload("res://SFX/Player/Sleep_1.wav"),
		preload("res://SFX/Player/Sleep_2.wav"),
	],
	Cue.ENEMY_SHOOT: [preload("res://SFX/Enemy/EneShoot.wav")],
	Cue.ENEMY_ATTACK: [preload("res://SFX/Enemy/enemySlash.wav")],
	Cue.ENEMY_DEATH: [preload("res://SFX/Enemy/EneDead.wav")],
	Cue.BOSS_CHARGE: [preload("res://SFX/Enemy/Boss_charge.mp3")],
	Cue.BOSS_SLASH: [preload("res://SFX/Enemy/Boss_slash.ogg")],
	Cue.BOSS_RADIAL: [preload("res://SFX/Enemy/Radial Attack.mp3")],
	Cue.ITEM_HEART: [preload("res://SFX/ItemSound/Heart.wav")],
	Cue.ITEM_COFFEE: [preload("res://SFX/ItemSound/Coffee.wav")],
	Cue.ITEM_LIGHTER: [preload("res://SFX/ItemSound/Lighter.wav")],
	Cue.ITEM_OIL_GOOD: [preload("res://SFX/ItemSound/Oil.wav")],
	Cue.ITEM_OIL_BAD: [preload("res://SFX/ItemSound/OilBad.wav")],
	Cue.ITEM_SHIELD: [preload("res://SFX/ItemSound/Shield.wav")],
	Cue.ITEM_SHOE: [preload("res://SFX/ItemSound/Shoe.wav")],
	Cue.ITEM_SHOE_FAST: [preload("res://SFX/ItemSound/Shoe_Fast.wav")],
	Cue.BOMB_EXPLOSION: [preload("res://SFX/ItemSound/Bomb.wav")],
	Cue.BOMB_FLY: [preload("res://SFX/ItemSound/BombFlying.wav")],
}

const CUE_VOLUME_DB := {
	Cue.PLAYER_SLEEP: 10.0,
	Cue.PLAYER_BLOCK: -5.0,
	Cue.ENEMY_ATTACK: -5.0,
	Cue.ENEMY_DEATH: -10.0,
	Cue.BOSS_CHARGE: -5.0,
	Cue.BOSS_SLASH: -5.0,
	Cue.BOSS_RADIAL: -5.0,
	Cue.ITEM_OIL_GOOD: 6.0,
	Cue.ITEM_OIL_BAD: 6.0,
	Cue.ITEM_SHIELD: 4.0,
	Cue.ITEM_SHOE: 6.0,
}

const PITCH_VARIATION_CUES := [Cue.PLAYER_SHOOT, Cue.ENEMY_SHOOT]
const CUE_LIMITS := {Cue.ENEMY_SHOOT: 4}

var _ost_manager: Node = null
var _current_wave: int = 0
var _active_sfx: Array[AudioStreamPlayer2D] = []
var _active_cue_counts: Dictionary = {}


func play_sfx(cue: int, world_position: Vector2, variant_seed: int) -> void:
	if not CUE_STREAMS.has(cue):
		return
	var active_count := int(_active_cue_counts.get(cue, 0))
	if active_count >= int(CUE_LIMITS.get(cue, 1_000_000)):
		return
	var streams: Array = CUE_STREAMS[cue]
	if streams.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed
	var player := AudioStreamPlayer2D.new()
	player.stream = streams[rng.randi_range(0, streams.size() - 1)]
	player.volume_db = float(CUE_VOLUME_DB.get(cue, 0.0))
	if cue in PITCH_VARIATION_CUES:
		player.pitch_scale = rng.randf_range(0.95, 1.05)
	player.global_position = world_position

	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(player)
	_active_sfx.append(player)
	_active_cue_counts[cue] = active_count + 1
	player.finished.connect(
		func() -> void:
			_active_sfx.erase(player)
			_active_cue_counts[cue] = maxi(int(_active_cue_counts.get(cue, 1)) - 1, 0)
			player.queue_free()
	)
	player.play()


func play_wave_music(wave_number: int) -> void:
	if wave_number <= 0 or wave_number == _current_wave:
		return
	_current_wave = wave_number
	if is_instance_valid(_ost_manager):
		_ost_manager.play_wave_ost(wave_number)


func stop_music() -> void:
	_current_wave = 0
	if is_instance_valid(_ost_manager):
		_ost_manager.stop_all()


func register_ost_manager(manager: Node) -> void:
	_ost_manager = manager
	if _current_wave > 0:
		_ost_manager.play_wave_ost(_current_wave)


func unregister_ost_manager(manager: Node) -> void:
	if _ost_manager == manager:
		_ost_manager = null


func reset() -> void:
	stop_music()
	for player in _active_sfx:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_sfx.clear()
	_active_cue_counts.clear()
