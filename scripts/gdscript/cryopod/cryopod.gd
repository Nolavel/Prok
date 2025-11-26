extends Node3D

@onready var anima: AnimationPlayer = $anima
@onready var interaction_area: Area3D = $interaction_area  # 🔥 Добавь Area3D как дочерний узел

var player_in_range: bool = false
var is_open: bool = false

func _ready() -> void:
	# Подключаем сигналы Area3D
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		print("✅ Cryopod: Area3D подключена")
	else:
		push_error("❌ Area3D не найдена! Добавь её как дочерний узел")

func _input(event: InputEvent) -> void:
	# Проверяем: игрок в зоне + нажата кнопка
	if Input.is_action_just_pressed("debug_info") and player_in_range:
		toggle_cryopod()

func toggle_cryopod() -> void:
	"""Переключает состояние криопода (открыт/закрыт)"""
	if is_open:
		# Закрываем
		anima.play_backwards("open_cryopod")
		is_open = false
		print("🔒 Криопод закрывается")
	else:
		# Открываем
		anima.play("open_cryopod")
		is_open = true
		print("🔓 Криопод открывается")

# === КОЛЛБЭКИ AREA3D ===
func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = true
		print("👤 Игрок вошёл в зону криопода")

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = false
		print("🚶 Игрок вышел из зоны криопода")
