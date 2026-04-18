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
