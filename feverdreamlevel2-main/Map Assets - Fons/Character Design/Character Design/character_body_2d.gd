extends CharacterBody2D

signal player_died

var health: int = 3
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func apply_hit() -> void:
	health -= 1
	print("Player hit! Health: %d" % health)

	if health <= 0:
		die()

func die() -> void:
	print("You Died!!")
	Engine.time_scale = 0.5
	collision_shape.queue_free()
	emit_signal("player_died")


# --- Movement Settings ---
@export var speed: float = 200
@export var jump_force: float = 350
@export var gravity: float = 1000
@export var dash_speed: float = 500
@export var dash_time: float = 0.7



# --- Drag your Skeleton2D (or visual root) here in the Inspector ---
@export var flip_node: Node2D

# --- Node References (resolved at runtime) ---
@onready var anim_tree: AnimationTree = $AnimationTree
var state_machine: AnimationNodeStateMachinePlayback

#Picked/ Throw
var canPick: bool = true

# --- Dash / Facing ---
var is_dashing := false
var dash_timer := 0.0
var facing_dir := 1  # 1 = right, -1 = left

func _ready() -> void:
	# Wire AnimationTree safely
	if anim_tree == null:
		push_error("AnimationTree not found at $AnimationTree. Update the path or add one.")
	else:
		anim_tree.active = true
		state_machine = anim_tree["parameters/playback"]  # requires StateMachine root

	# Auto-detect a visual if you forgot to set Flip Node
	if flip_node == null:
		flip_node = get_node_or_null("Skeleton2D")
		if flip_node == null:
			flip_node = get_node_or_null("Sprite2D")
		if flip_node == null:
			flip_node = get_node_or_null("AnimatedSprite2D")
	if flip_node == null:
		push_error("Flip node not set/found. In the Inspector, set 'Flip Node' to your Skeleton2D.")

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		_travel("Jump_D")

	var input_dir := Input.get_axis("ui_left", "ui_right")
	
	

	# Dash movement
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
		velocity.x = dash_speed * facing_dir
		_travel("Dash")

	# Duck
	elif Input.is_action_pressed("ui_down") and is_on_floor():
		velocity.x = 0
		_travel("Duck")

	# Run
	elif Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"):
		velocity.x = input_dir * speed
		_face_direction(input_dir)
		_travel("Run")

	# Idle
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		if is_on_floor():
			_travel("Idle")
		
	
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force
		_travel("Jump")
		
	#Melee Idle
	elif Input.is_action_pressed("ui_AttackM") and is_on_floor() and input_dir == 0 and not is_dashing:
		_travel("AttackM_2")

	# Melee Run
	elif Input.is_action_just_pressed("ui_AttackM") and is_on_floor() and input_dir != 0 and not is_dashing:
		_travel("Run_Attack")
			

	# Melee Air Dash
	elif Input.is_action_pressed("ui_AttackM") and is_dashing and input_dir == 0:
		_travel("Attack_Air")
	
		# Melee Air Dash
	elif Input.is_action_pressed("ui_AttackM") and is_dashing and input_dir != 0:
		_travel("Attack_Air")


	
	
	# Melee Air Jump
	elif Input.is_action_just_pressed("ui_AttackM") and not is_on_floor():
		_travel("Attack_Air")
		
	# Range
	elif Input.is_action_pressed("ui_AttackR") and is_on_floor():
		velocity.x = 0
		_travel("AttackR")

	# Dash start
	if Input.is_action_just_pressed("ui_Dash") and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		if input_dir != 0.0:
			facing_dir = sign(input_dir)
		velocity.x = dash_speed * facing_dir
		_travel("Dash")

	move_and_slide()

# --- Animation helper ---
func _travel(state: String) -> void:
	if state_machine != null:
		state_machine.travel(state)

# --- Flip helper (works for Skeleton2D, Sprite2D, AnimatedSprite2D) ---
func _face_direction(dir: float) -> void:
	if dir < 0 and facing_dir != -1:
		facing_dir = -1
		_set_flip_x(-1)
	elif dir > 0 and facing_dir != 1:
		facing_dir = 1
		_set_flip_x(1)

func _set_flip_x(sign_x: int) -> void:
	if flip_node == null: 
		return
	# preserve existing scale magnitude; only change the sign of X
	var sx := flip_node.scale.x
	var sy := flip_node.scale.y
	flip_node.scale = Vector2(sign_x * abs(sx if sx != 0.0 else 1.0), sy if sy != 0.0 else 1.0)
