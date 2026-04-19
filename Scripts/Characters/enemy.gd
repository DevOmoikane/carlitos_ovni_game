extends CharacterBody3D

# Enemy settings
@export var speed: float = 5.0
@export var health: int = 5
@export var score_value: int = 100

# Movement pattern
@export var movement_amplitude: float = 0.0
@export var movement_frequency: float = 1.0

# References
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var area_detection: Area3D = $DetectionArea

var start_position: Vector3
var time: float = 0.0

func _ready():
	start_position = position
	
	# Add to enemy group for collision detection
	add_to_group("enemy")
	
	# Setup detection area if not exists
	if not area_detection:
		setup_detection_area()
	
	# Setup visual effects
	#setup_enemy_visuals()

func setup_detection_area():
	area_detection = Area3D.new()
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.343
	collision.shape = sphere_shape
	area_detection.add_child(collision)
	add_child(area_detection)

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

func destroy():
	# Create explosion effect
	create_explosion()
	
	# Emit destroyed signal (for score)
	if has_signal("destroyed"):
		destroyed.emit(self)
	
	# Remove enemy
	queue_free()

func create_explosion():
	var explosion = GPUParticles3D.new()
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 3.0
	particle_material.initial_velocity_max = 8.0
	particle_material.scale_min = 0.2
	particle_material.scale_max = 0.5
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.YELLOW)
	gradient.add_point(0.5, Color.ORANGE)
	gradient.add_point(1.0, Color.RED)
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	particle_material.color_ramp = color_ramp
	
	explosion.process_material = particle_material
	explosion.emitting = true
	explosion.amount = 500
	explosion.lifetime = 0.8
	explosion.one_shot = true
	explosion.position = global_position
	
	get_tree().root.add_child(explosion)
	
	await get_tree().create_timer(1.8).timeout
	explosion.queue_free()

signal destroyed

func _on_area_entered(area):
	if area.is_in_group("projectile"):
		health -= 1
		if health <= 0:
			destroy()
