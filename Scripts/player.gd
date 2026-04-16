extends CharacterBody2D

@export var input_prefix: String = "p1_"
@export var speed: float = 125.0

@export var max_stamina: float = 100.0
var current_stamina: float = 100.0
@export var depletion_rate: float = 10.0
@export var recharge_rate: float = 5.0

var is_sleeping: bool = false
var ghost_scene = preload("res://Scenes/player_ghost.tscn")
var active_ghost: CharacterBody2D = null

var knockback_velocity: Vector2 = Vector2.ZERO

@onready var stamina_bar = $Stats/StaminaBar


func _ready():
	stamina_bar.max_value = max_stamina
	stamina_bar.value = max_stamina


func _physics_process(delta: float) -> void:
	if is_sleeping:
		handle_sleep(delta)
		return

	var direction = Input.get_vector(
		input_prefix + "move_left",
		input_prefix + "move_right",
		input_prefix + "move_up",
		input_prefix + "move_down"
	)

	var move_velocity = direction * speed
	velocity = move_velocity + knockback_velocity
	knockback_velocity *= 0.85

	if direction != Vector2.ZERO:
		consume_stamina(delta)
	else:
		velocity = knockback_velocity

	move_and_slide()
	update_ui()


func consume_stamina(delta):
	current_stamina -= depletion_rate * delta
	if current_stamina <= 0:
		enter_sleep()


func enter_sleep():
	is_sleeping = true
	velocity = Vector2.ZERO
	modulate = Color(0.5, 0.5, 1.0) # Turn slightly blue/dark to show sleeping
	
	active_ghost = ghost_scene.instantiate()
	active_ghost.input_prefix = input_prefix # Give the ghost your controls
	active_ghost.global_position = global_position # Start at player's body
	get_parent().add_child(active_ghost)
	
func handle_sleep(delta):
	current_stamina += recharge_rate * delta

	if current_stamina >= max_stamina:
		wake_up()

func wake_up():
	is_sleeping = false
	modulate = Color(1, 1, 1)
	if active_ghost:
		active_ghost.queue_free() # Remove the ghost when waking up

func update_ui():
	stamina_bar.value = current_stamina

func apply_knockback(force: Vector2):
	knockback_velocity = force
