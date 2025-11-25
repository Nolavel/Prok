extends Node3D

# Узел-маркер в сцене уровня
@onready var spawn_point: Marker3D = $SpawnerPlayer
@onready var player = $Player

func _ready() -> void:
	player.global_transform = spawn_point.global_transform
