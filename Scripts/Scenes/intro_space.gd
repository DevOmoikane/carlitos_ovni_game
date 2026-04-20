extends Node3D

# References
@onready var player = $Player
@onready var earth = $Earth
@onready var path_follow = $EnterPath/PathFollow3D
@onready var ready_follow = $ReadyPath/PathFollow3D

# Misc spawning
@export var earth_scale_rate: float = 3

var state: int = 0

func _ready():
	state = 0
	path_follow.progress_ratio = 0.0
	player.global_position = path_follow.global_position
	player.rotation = path_follow.rotation

func _input(event):
	pass

func _process(delta):
	pass
	
func _physics_process(delta: float) -> void:
	earth.rotate_y(0.001)
	if earth.scale.x >= 10:
		print("Got to the end")
	if state == 0:
		if path_follow.progress_ratio < 1.0:
			player.global_position = path_follow.global_position
			player.rotation = path_follow.rotation
			path_follow.progress_ratio += 0.005
			if path_follow.progress_ratio == 1.0:
				state = 1
	elif state == 2:
		if ready_follow.progress_ratio < 1.0:
			player.global_position = ready_follow.global_position
			player.rotation = ready_follow.rotation
			ready_follow.progress_ratio += 0.005
			if ready_follow.progress_ratio == 1.0:
				get_tree().change_scene_to_file("res://Scenes/gameplay_space.tscn")

func _on_button_pressed() -> void:
	if not state == 2:
		state = 2
		ready_follow.progress_ratio = 0.0
		player.global_position = ready_follow.global_position
		player.rotation = ready_follow.rotation
