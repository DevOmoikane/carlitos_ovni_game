extends CharacterBody3D

# Movement settings
@export var max_speed: float = 15.0
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var smooth_factor: float = 5.0

# Rotation settings (Z-axis roll)
@export var max_roll_angle: float = 30.0  # degrees
@export var roll_speed: float = 8.0
@export var return_speed: float = 8.0

# Boundaries
@export var x_boundary: float = 4.2
@export var use_boundaries: bool = true

# Particle settings
@export var particle_emission_rate: float = 20.0  # Particles per second
@export var particle_speed: float = 5.0
@export var particle_colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW, Color.CYAN, Color.MAGENTA]

# Light settings
@export var blink_speed: float = 2.0  # Blinks per second
@export var light_intensity: float = 2.0
@export var light_range: float = 3.0

# Debug settings
@export var debug_mode: bool = false

# Add these with other export variables at the top
@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.1  # Seconds between shots
@export var projectile_spawn_offset: Vector3 = Vector3(0, 0.2, -0.5)

@export var user_movement: bool = true

# Add these with other variables
var can_shoot: bool = true
var shoot_timer: Timer

# Mouse tracking
var mouse_velocity: float = 0.0
var current_movement: float = 0.0
var target_movement: float = 0.0
var target_roll: float = 0.0
var current_roll: float = 0.0
var last_mouse_position: Vector2
var mouse_stop_timer: float = 0.0

# References
@onready var mesh_instance: MeshInstance3D = $mesh
@onready var collision_shape: CollisionShape3D = $collisionShape
@onready var particle_system: GPUParticles3D = $EngineParticles
@onready var left_light: OmniLight3D = $mesh/LeftLight
@onready var right_light: OmniLight3D = $mesh/RightLight
@onready var blink_timer: Timer = $BlinkTimer
@onready var collision_area: Area3D = $Area3D

# Particle system references
var particle_material: ParticleProcessMaterial

func _ready():
	print("Spaceship ready with effects!")
	
	add_to_group("player")
	#collision_area.add_to_group("player")
	
	# Setup particle system
	setup_particle_system()
	
	# Setup blinking lights
	setup_blinking_lights()
	
	# Check required nodes
	if not mesh_instance:
		print("WARNING: MeshInstance3D not found!")
	
	# Initialize mouse position
	var viewport = get_viewport()
	if viewport:
		last_mouse_position = viewport.get_mouse_position()
		
	# Setup shooting
	setup_shooting()
	
	user_movement = true

func setup_particle_system():
	# Create particle system if it doesn't exist
	if not particle_system:
		particle_system = GPUParticles3D.new()
		particle_system.name = "EngineParticles"
		add_child(particle_system)
	
	# Configure particle system
	particle_system.emitting = true
	particle_system.explosiveness = 0.0
	particle_system.lifetime = 1.5
	particle_system.one_shot = false
	particle_system.amount = 800
	particle_system.speed_scale = 1.0
	
	# Set emission shape (box shape behind the ship)
	var emission_shape = BoxShape3D.new()
	emission_shape.size = Vector3(1.0, 0.5, 0.5)
	
	# Create particle material
	particle_material = ParticleProcessMaterial.new()
	
	# Set particle properties
	particle_material.direction = Vector3(0, 0, -1)  # Move in positive Z (backward)
	particle_material.spread = 30.0  # Spread angle
	particle_material.initial_velocity_min = particle_speed
	particle_material.initial_velocity_max = particle_speed * 1.5
	particle_material.angular_velocity_min = -5.0
	particle_material.angular_velocity_max = 5.0
	particle_material.scale_min = 0.1
	particle_material.scale_max = 0.3
	particle_material.gravity = Vector3(0, -1, 0)  # Slight downward gravity
	
	# Enable color cycling
	particle_material.color_ramp = create_color_ramp()
	
	# Apply material
	particle_system.process_material = particle_material
	
	# Set particle position to back of ship
	particle_system.position = Vector3(0, -0.4, 0.0)
	
	print("Particle system setup complete")

func create_color_ramp():
	# Create a gradient for color cycling
	var gradient = Gradient.new()
	
	# Add colors to gradient
	var offset = 0.0
	var step = 1.0 / particle_colors.size()
	for color in particle_colors:
		gradient.add_point(offset, color)
		offset += step
	
	# Create color ramp texture
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	
	return color_ramp

func setup_blinking_lights():
	# Create left light if it doesn't exist
	if not left_light:
		left_light = OmniLight3D.new()
		left_light.name = "LeftLight"
		add_child(left_light)
	
	# Create right light if it doesn't exist
	if not right_light:
		right_light = OmniLight3D.new()
		right_light.name = "RightLight"
		add_child(right_light)
	
	# Configure left light (red)
	left_light.light_color = Color.RED
	left_light.light_energy = light_intensity
	left_light.position = Vector3(-1.2, 0.2, 0)  # Left side of ship
	
	# Configure right light (blue)
	right_light.light_color = Color.BLUE
	right_light.light_energy = light_intensity
	right_light.position = Vector3(1.2, 0.2, 0)  # Right side of ship
	
	# Add optional light glow effect
	add_light_glow(left_light)
	add_light_glow(right_light)
	
	# Start blinking
	if not blink_timer:
		blink_timer = Timer.new()
		blink_timer.name = "BlinkTimer"
		add_child(blink_timer)
	
	blink_timer.wait_time = 1.0 / blink_speed
	blink_timer.timeout.connect(_blink_lights)
	blink_timer.start()

func add_light_glow(light: OmniLight3D):
	# Add an OmniLight3D for glow effect (if using Godot 4 with glow)
	var glow_light = OmniLight3D.new()
	glow_light.light_color = light.light_color
	glow_light.light_energy = light.light_energy * 0.5
	glow_light.position = Vector3.ZERO
	light.add_child(glow_light)

func _blink_lights():
	# Toggle lights with alternating pattern
	if left_light and right_light:
		# Alternate blinking pattern
		var left_state = (Time.get_ticks_msec() / 100) % 2 == 0
		var right_state = not left_state
		
		left_light.light_energy = light_intensity if left_state else 0
		right_light.light_energy = light_intensity if right_state else 0
		
		# Add pulse effect
		var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.01) * 0.5
		if left_light.light_energy > 0:
			left_light.light_energy = light_intensity * (0.7 + pulse * 0.3)
		if right_light.light_energy > 0:
			right_light.light_energy = light_intensity * (0.7 + pulse * 0.3)

# Add new function for shooting setup
func setup_shooting():
	# Create timer for shooting cooldown
	shoot_timer = Timer.new()
	shoot_timer.name = "ShootTimer"
	shoot_timer.wait_time = fire_rate
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_cooldown_end)
	add_child(shoot_timer)
	
# Public method for main scene to call with input
func handle_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_stop_timer = 0.0
		
		var mouse_delta_x = event.relative.x
		var delta = get_process_delta_time()
		
		mouse_velocity = mouse_delta_x / delta
		mouse_velocity = clamp(mouse_velocity, -800, 800)
		
		target_movement = mouse_velocity / 400.0
		target_movement = clamp(target_movement, -1.0, 1.0)
		
		target_roll = -target_movement * max_roll_angle
		
		if debug_mode and abs(mouse_delta_x) > 5:
			print("Mouse Delta: ", mouse_delta_x, " | Target Movement: ", "%.2f" % target_movement)
		
		last_mouse_position = event.position
		
		# Increase particle emission during movement
		update_particle_emission()
		
	# Handle shooting with left mouse button
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot()

# Add new shooting functions
func shoot():
	if not can_shoot:
		return
	
	if not projectile_scene:
		print("ERROR: Projectile scene not assigned!")
		return
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# IMPORTANT: Add projectile to scene BEFORE setting position
	get_tree().root.add_child(projectile)
	
	# Now set the position after it's in the scene tree
	var spawn_position = global_position + projectile_spawn_offset
	
	# Apply slight spread based on ship movement
	var spread = current_movement * 0.5
	spawn_position.x += spread
	
	projectile.global_position = spawn_position
	
	# Start cooldown
	can_shoot = false
	shoot_timer.start()
	
	# Play shooting effect
	create_shoot_effect()
	create_bubble_effect("pewpew.png", 0.3)

func create_bubble_effect(image_path: String, duration: float):
	var texture = load("res://Assets/Textures/" + image_path)
	if not texture:
		return
	
	var sprite = Sprite3D.new()
	sprite.texture = texture
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.position = Vector3(global_position.x + projectile_spawn_offset.x, global_position.y + projectile_spawn_offset.y, global_position.z + projectile_spawn_offset.z)
	sprite.scale = Vector3(0.4, 0.4, 0.4)
	
	get_tree().current_scene.add_child(sprite)
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): sprite.queue_free())

func create_shoot_effect():
	# Create muzzle flash effect
	var flash = OmniLight3D.new()
	flash.light_color = Color.CYAN
	flash.light_energy = 2.0
	flash.position = projectile_spawn_offset
	add_child(flash)
	
	# Remove flash after short time
	await get_tree().create_timer(0.05).timeout
	flash.queue_free()
	
	# Add shooting particles
	if particle_system:
		var original_amount = particle_system.amount
		particle_system.amount = 200
		await get_tree().create_timer(0.1).timeout
		particle_system.amount = original_amount

func _on_shoot_cooldown_end():
	can_shoot = true

func update_particle_emission():
	# Increase particle emission based on movement intensity
	if particle_system:
		var intensity = abs(current_movement)
		var emission_multiplier = 1.0 + intensity * 3.0
		particle_system.speed_scale = emission_multiplier
		
		# Change particle color based on movement intensity
		if particle_material and intensity > 0.5:
			# Make particles brighter during intense movement
			particle_material.initial_velocity_min = particle_speed * (1 + intensity)
			particle_material.initial_velocity_max = particle_speed * 1.5 * (1 + intensity)

func _physics_process(delta):
	if not user_movement:
		return
	# Update mouse stop timer
	mouse_stop_timer += delta
	
	# If mouse hasn't moved for more than 0.1 seconds, consider it stopped
	if mouse_stop_timer > 0.1:
		target_movement = move_toward(target_movement, 0.0, return_speed * delta)
		target_roll = move_toward(target_roll, 0.0, return_speed * delta)
		mouse_velocity = move_toward(mouse_velocity, 0.0, return_speed * delta)
		
		if abs(target_movement) < 0.01:
			target_movement = 0.0
			target_roll = 0.0
	
	# Smoothly interpolate current movement
	current_movement = lerp(current_movement, target_movement, smooth_factor * delta)
	
	# Calculate desired velocity
	var desired_velocity_x = current_movement * max_speed
	
	# Apply acceleration or deceleration
	if abs(desired_velocity_x) > 0.01:
		velocity.x = move_toward(velocity.x, desired_velocity_x, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	
	# Apply movement with boundary limits
	if use_boundaries:
		var new_x = position.x + velocity.x * delta
		if abs(new_x) <= x_boundary:
			position.x = new_x
		else:
			position.x = sign(new_x) * x_boundary
			velocity.x = 0
			target_movement = 0
			current_movement = 0
	else:
		move_and_slide()
	
	# Smoothly interpolate roll rotation
	current_roll = lerp(current_roll, target_roll, roll_speed * delta)
	
	# Apply rotation to the mesh
	if mesh_instance:
		mesh_instance.rotation.z = deg_to_rad(current_roll)
	
	# Update particle system position to follow ship's movement
	update_effects(delta)

func update_effects(delta):
	# Update particle emission based on movement
	update_particle_emission()
	
	# Create trail effect based on movement
	if abs(velocity.x) > 2.0:
		create_movement_trail()
	
	# Update light intensity based on movement
	var intensity = abs(current_movement)
	if left_light and right_light:
		var base_intensity = light_intensity * (0.5 + intensity * 0.5)
		if left_light.light_energy > 0:
			left_light.light_energy = base_intensity
		if right_light.light_energy > 0:
			right_light.light_energy = base_intensity

func create_movement_trail():
	# Create temporary trail particles when moving fast
	if particle_system and abs(velocity.x) > 5.0:
		# Temporarily increase particle emission
		particle_system.amount = 150
		# Schedule reset after a short time
		await get_tree().create_timer(0.1).timeout
		particle_system.amount = 100

func get_movement_intensity() -> float:
	return abs(current_movement)

func get_movement_direction() -> float:
	return sign(current_movement)

func get_current_speed() -> float:
	return abs(velocity.x)

func is_moving() -> bool:
	return abs(velocity.x) > 0.5

# Cleanup
func _exit_tree():
	if blink_timer:
		blink_timer.stop()
