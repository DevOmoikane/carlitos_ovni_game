extends Area3D

# Enemy settings
@export var speed: float = 5.0
@export var health: int = 3
@export var score_value: int = 100

# Movement pattern
@export var movement_amplitude: float = 0.0
@export var movement_frequency: float = 1.0

# References
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var start_position: Vector3
var time: float = 0.0

func _ready():
	start_position = position
	
	# Add to enemy group for collision detection
	add_to_group("enemy")
	
	# Setup visual effects
	#setup_enemy_visuals()
	
	body_entered.connect(_on_collision)
	area_entered.connect(_on_collision)

func setup_enemy_visuals():
	# Add a simple red material to enemy
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.RED
		material.emission_enabled = true
		material.emission = Color.RED
		material.emission_energy = 0.9
		mesh_instance.material_override = material

func _physics_process(delta):
	time += delta
	
	# Move forward
	position.z += speed * delta
	
	# Optional: Sine wave movement
	position.x = start_position.x + sin(time * movement_frequency) * movement_amplitude
	
	# Remove if off screen
	if position.z > 15:
		queue_free()

func update_ai(player_position: Vector3, delta):
	# Simple AI - move towards player's X position
	var target_x = player_position.x
	position.x = move_toward(position.x, target_x, speed * 0.5 * delta)
	
	# Move forward
	position.z += speed * delta

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		if has_signal("destroyed"):
			emit_signal("destroyed")
		destroy()

func destroy():
	create_explosion()
	create_bubble_effect("boom.png", 0.75)
	queue_free()

func create_bubble_effect(image_path: String, duration: float):
	var texture = load("res://Assets/Textures/" + image_path)
	if not texture:
		return
	
	var sprite = Sprite3D.new()
	sprite.texture = texture
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.position = Vector3(global_position.x, global_position.y, global_position.z)
	sprite.scale = Vector3(0.7, 0.7, 0.7)
	
	get_tree().current_scene.add_child(sprite)
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): sprite.queue_free())

func create_explosion():
	var explosion = GPUParticles3D.new()
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 3.0
	particle_material.initial_velocity_max = 8.0
	particle_material.scale_min = 0.2
	particle_material.scale_max = 0.5
	particle_material.gravity = Vector3(0.0, 0.0, 0.0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.YELLOW)
	gradient.add_point(0.5, Color.ORANGE)
	gradient.add_point(1.0, Color.RED)
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	particle_material.color_ramp = color_ramp
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	
	explosion.process_material = particle_material
	explosion.draw_pass_1 = mesh
	explosion.emitting = true
	explosion.amount = 500
	explosion.lifetime = 0.8
	explosion.one_shot = true
	explosion.position = global_position
	
	get_tree().current_scene.add_child(explosion)
	
	await get_tree().create_timer(1.0).timeout
	explosion.queue_free()

func _on_collision(collider):
	if collider.is_in_group("player"):
		if has_signal("hit_player"):
			emit_signal("hit_player")
		queue_free()
		
signal destroyed
signal hit_player
