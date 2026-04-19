extends Area3D

# Projectile settings
@export var speed: float = 20.0
@export var damage: int = 1
@export var lifetime: float = 3.0

# Visual effects
@export var projectile_color: Color = Color.CYAN
@export var trail_enabled: bool = true

# References
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var gpu_particles: GPUParticles3D

func _ready():
	# Set up projectile appearance
	setup_projectile()
	add_to_group("projectile")	
	# Automatically remove after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func setup_projectile():
	# Create a simple mesh if not present
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.2
		sphere_mesh.height = 0.4
		mesh_instance.mesh = sphere_mesh
		add_child(mesh_instance)
	
	# Create collision shape if not present
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.2
		collision_shape.shape = sphere_shape
		add_child(collision_shape)
	
	# Set material color
	var material = StandardMaterial3D.new()
	material.albedo_color = projectile_color
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy = 0.5
	mesh_instance.material_override = material
	
	# Add trail particles
	if trail_enabled and not gpu_particles:
		setup_trail_particles()
	
	# Connect collision signal
	body_entered.connect(_on_collision)
	area_entered.connect(_on_collision)

func setup_trail_particles():
	gpu_particles = GPUParticles3D.new()
	gpu_particles.name = "TrailParticles"
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 0, -1)
	particle_material.spread = 15.0
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 3.0
	particle_material.scale_min = 0.05
	particle_material.scale_max = 0.1
	particle_material.gravity = Vector3(0, 0, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, projectile_color)
	gradient.add_point(1.0, Color.TRANSPARENT)
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	particle_material.color_ramp = color_ramp
	
	gpu_particles.process_material = particle_material
	gpu_particles.emitting = true
	gpu_particles.amount = 50
	gpu_particles.lifetime = 0.5
	gpu_particles.one_shot = false
	
	add_child(gpu_particles)

func _physics_process(delta):
	# Move projectile forward (negative Z direction)
	position.z -= speed * delta

func _on_collision(collider):
	if collider.is_in_group("enemy"):
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
		else:
			collider.queue_free()
		create_hit_effect(collider.global_position)
		queue_free()
	elif not collider.is_in_group("player"):
		create_hit_effect(global_position)
		queue_free()
		
func _on_area_entered(area):
	print("hitted " + area)
	pass
			
func create_hit_effect(position: Vector3):
	var explosion = GPUParticles3D.new()
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 5.0
	particle_material.scale_min = 0.1
	particle_material.scale_max = 0.3
	particle_material.gravity = Vector3(0, 0, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.YELLOW)
	gradient.add_point(0.5, Color.ORANGE)
	gradient.add_point(1.0, Color.RED)
	
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	particle_material.color_ramp = color_ramp
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	
	explosion.process_material = particle_material
	explosion.draw_pass_1 = mesh
	explosion.emitting = true
	explosion.amount = 30
	explosion.lifetime = 0.5
	explosion.one_shot = true
	explosion.position = position
	
	get_tree().current_scene.add_child(explosion)
	
	await get_tree().create_timer(0.6).timeout
	explosion.queue_free()
