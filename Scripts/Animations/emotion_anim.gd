extends Node2D

class_name EmotionAnim

@onready var sprite = $Sprite
@onready var animation_player = $AnimationPlayer

#const x_sprite = preload("res://Assets/Graphics/Emotions/x.png")

func _play():
	#animation_player.play("animate")
	pass
	
func play_love():
	#sprite.set_texture(x_sprite)
	_play()

func destroy(time):
	await get_tree().create_timer(time).timeout
	queue_free()
