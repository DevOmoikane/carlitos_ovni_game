extends Node3D

# References
@onready var player = $Player
@onready var earth = $Earth
@onready var path = $Path3D
@onready var out_path_follow = $Path3D/PathFollow3D

# Misc spawning
@export var earth_scale_rate: float = 3

# Enemy spawning
@export var enemy_scene: PackedScene
@export var spawn_timer_duration: float = 3.0
@export var max_enemies: int = 10

# Object spawning
@export var powerup_scene: PackedScene
@export var obstacle_scene: PackedScene
@export var object_spawn_timer_duration: float = 5.0

# Game state
var score: int = 0
var health: int = 300
var enemies: Array = []
var objects: Array = []
var spawn_timer: Timer
var object_timer: Timer
var out_state: bool = false
var current_earth_angle: float = 0.0

func _ready():
	print("Main scene ready - Looking for player...")
	
	# Find player if not set correctly
	if not player:
		print("no player :(")
		player = find_child("Player", true, false)
		if player:
			print("Player found: ", player.name)
		else:
			print("ERROR: Could not find player node! Make sure your player is named 'Player'")
			return
	
	# Enable input processing
	#set_process_input(true)
	
	# Capture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Mouse captured - Move mouse side to side to control the ship")
	
	if earth:
		earth.global_position = Vector3(-5.54, -26.6, -66.0)
		earth.global_rotation = Vector3(0.0, -92.2, 0.0)
		earth.scale = Vector3(0.21, 0.21, 0.21)
	# Start spawning enemies and objects
	start_spawning()

func _input(event):
	# Pass input events to the player
	if not out_state and player and player.has_method("handle_input"):
		player.handle_input(event)
	
	# Handle Escape key to release/capture mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			print("Mouse released - Press ESC again or click to capture")
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			print("Mouse captured - Move mouse to control ship")
	
	# Click to recapture mouse when visible
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			print("Mouse captured via click")

func start_spawning():
	# Create timer for enemies
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_timer_duration
	spawn_timer.timeout.connect(_spawn_enemy)
	spawn_timer.autostart = true
	add_child(spawn_timer)
	
	# Create timer for objects
	#object_timer = Timer.new()
	#object_timer.wait_time = object_spawn_timer_duration
	#object_timer.timeout.connect(_spawn_object)
	#object_timer.autostart = true
	#add_child(object_timer)
	
	print("Spawning system started")

# Add to _spawn_enemy function
func _spawn_enemy():
	if not enemy_scene or out_state:
		return
		
	if enemies.size() >= max_enemies:
		return
	
	var enemy = enemy_scene.instantiate()
	var random_x = randf_range(-4.2, 4.2)
	var spawn_z = -50.0
	
	enemy.position = Vector3(random_x, 0, spawn_z)
	
	add_child(enemy)
	enemies.append(enemy)
	
	# Connect destroyed signal
	if enemy.has_signal("destroyed"):
		enemy.destroyed.connect(_on_enemy_destroyed.bind(enemy))
	if enemy.has_signal("hit_player"):
		enemy.hit_player.connect(_on_enemy_hit_player.bind(enemy))

func _spawn_object():
	if out_state:
		return
		
	var object_type = randi() % 3  # 0: powerup, 1: obstacle, 2: collectable
	
	var object_instance = null
	
	match object_type:
		0:
			if powerup_scene:
				object_instance = powerup_scene.instantiate()
		1:
			if obstacle_scene:
				object_instance = obstacle_scene.instantiate()
		2:
			# You can add a collectable scene here if you have one
			pass
	
	if not object_instance:
		return
	
	# Position object
	var random_x = randf_range(-18, 18)
	var spawn_z = -25.0
	
	object_instance.position = Vector3(random_x, 0, spawn_z)
	
	add_child(object_instance)
	objects.append(object_instance)

# Add this new function for handling enemy destruction
func _on_enemy_destroyed(enemy):
	score += 100
	update_score_display()
	
	# Remove from array
	enemies.erase(enemy)
	
	# Optional: Play sound effect
	# $AudioStreamPlayer3D.play()

func _on_enemy_hit_player(enemy):
	health -= 20
	if health <= 0:
		print("died")
		
func update_score_display():
	# Update UI if you have one
	if has_node("UI/ScoreLabel"):
		$UI/ScoreLabel.text = "Score: " + str(score)
	else:
		print("Score: ", score)  # Debug output

func _process(delta):
	if not player:
		print("...no player :(")
		return
	
	# Update enemy AI
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("update_ai"):
			enemy.update_ai(player.global_position, delta)
		elif is_instance_valid(enemy):
			# Simple movement for enemies without AI
			enemy.position.z += delta * 5.0
	
	# Update object movement (move towards player)
	for obj in objects:
		if is_instance_valid(obj):
			obj.position.z += delta * 8.0
	
	# Remove off-screen objects (behind player)
	objects = objects.filter(func(obj): 
		return is_instance_valid(obj) and obj.position.z < 15
	)
	
	enemies = enemies.filter(func(enemy): 
		return is_instance_valid(enemy) and enemy.position.z < 15
	)
	
func _physics_process(delta: float) -> void:
	if not out_state and earth.scale.x < 5.0:
		earth.scale += Vector3(earth_scale_rate / 1000, earth_scale_rate / 1000, earth_scale_rate / 1000)
		earth.rotate_y(0.001)
	elif not out_state and earth.scale.x >= 5.0:
		out_state = true
		player.user_movement = false
		out_path_follow.progress_ratio = 0.0
		player.global_position = out_path_follow.global_position
		player.rotation = out_path_follow.rotation
		current_earth_angle = earth.rotation.y
	elif out_state:
		if out_path_follow.progress_ratio < 1.0:
			out_path_follow.progress_ratio += 0.001
		if out_path_follow.progress_ratio <= 0.90:
			earth.rotation.y = lerpf(current_earth_angle, 269.0, 0.1 * delta)
			player.global_position = out_path_follow.global_position
			player.rotation = out_path_follow.rotation
		if out_path_follow.progress_ratio > 0.90:
			player.global_position = out_path_follow.global_position
			player.rotation = out_path_follow.rotation
			var lerp_scale = lerp(1.0, 0.01, 0.1 * delta)
			player.scale = Vector3(lerp_scale, lerp_scale, lerp_scale)

# Debug: Press F3 to show debug info
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		print("=== DEBUG INFO ===")
		print("Mouse Mode: ", Input.get_mouse_mode())
		print("Player Position: ", player.position if player else "No player")
		print("Enemies: ", enemies.size())
		print("Objects: ", objects.size())
		print("Score: ", score)
		print("=================")
