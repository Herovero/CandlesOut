extends Node

@warning_ignore("unused_signal")
signal take_damage(amount: float, player_id: String)

@warning_ignore("unused_signal")
signal game_over(reason: String)

# item effects
@warning_ignore("unused_signal")
signal restore_stamina(amount: float, player_id: String)
@warning_ignore("unused_signal")
signal apply_speed_boost(speed_multiplier: float, duration: float, player_id: String)
@warning_ignore("unused_signal")
signal apply_triple_shot(duration: float, player_id: String)
@warning_ignore("unused_signal")
signal swap_player()

# item effects (losing control)
@warning_ignore("unused_signal")
signal apply_flamethrower_backfire(duration: float, player_id: String)
@warning_ignore("unused_signal")
signal apply_speed_backfire(multiplier: float, duration: float, player_id: String)

# ghost mode
@warning_ignore("unused_signal")
signal ghost_mode_started
@warning_ignore("unused_signal")
signal ghost_mode_ended

# boss UI / phase flow
@warning_ignore("unused_signal")
signal boss_hp_init(boss: Node, current_hp: float, max_hp: float, is_phase_two: bool)
@warning_ignore("unused_signal")
signal boss_hp_changed(current_hp: float, max_hp: float, is_phase_two: bool)
@warning_ignore("unused_signal")
signal boss_phase_two_transition_started
@warning_ignore("unused_signal")
signal boss_phase_two_activated(phase_two_max_hp: float)
@warning_ignore("unused_signal")
signal boss_activate_phase_two
@warning_ignore("unused_signal")
signal boss_defeated
