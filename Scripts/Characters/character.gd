extends CharacterBody2D

class_name Character

const EMOTION_ANIM_SCENE = preload("res://Scenes/Animations/emotion_anim.tscn")

func instantiate_anim(time = 1.0, offset_x = 0.0, offset_y = 0.0) -> EmotionAnim:
	var instance = EMOTION_ANIM_SCENE.instantiate()
	add_child(instance)
	instance.destroy(time)
	instance.global_position = Vector2(global_position.x + offset_x, global_position.y + offset_y)
	return instance
