extends Node3D

@onready var anim = $Anima

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	anim.play("Scene_BEGIN")
	await get_tree().create_timer(12.0).timeout
	get_tree().quit()
