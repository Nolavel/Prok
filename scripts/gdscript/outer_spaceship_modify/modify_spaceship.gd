extends Node3D

@export var outer_camera: Camera3D
@export var side_engine_left: MeshInstance3D
@export var side_engine_right: MeshInstance3D
@export var engine_aft: MeshInstance3D

# Угол полета и приземления (в градусах)
const FLIGHT_ANGLE = -90.0
const LANDING_ANGLE = 0.0
const ROTATION_DURATION = 10.0

# Текущее состояние двигателей
var is_landing_mode = false
var is_rotating = false

# Tween для анимации
var tween: Tween

func _ready():
	# Устанавливаем начальное положение двигателей (режим полета)
	set_engines_rotation(FLIGHT_ANGLE)

func _process(_delta):
	# Проверяем нажатие Ctrl
	if Input.is_key_pressed(KEY_CTRL):
		toggle_engines()

func toggle_engines():
	# Если уже идет поворот - игнорируем нажатие
	if is_rotating:
		return
	
	# Определяем целевой угол
	var target_angle = LANDING_ANGLE if not is_landing_mode else FLIGHT_ANGLE
	
	# Запускаем анимацию
	rotate_engines(target_angle)
	
	# Переключаем режим
	is_landing_mode = not is_landing_mode

func rotate_engines(target_angle: float):
	is_rotating = true
	
	# Убиваем предыдущий Tween если он есть
	if tween:
		tween.kill()
	
	# Создаем новый Tween
	tween = create_tween()
	tween.set_parallel(true)  # Все движки поворачиваются одновременно
	tween.set_trans(Tween.TRANS_CUBIC)  # Плавная интерполяция
	tween.set_ease(Tween.EASE_IN_OUT)  # Плавное начало и конец
	
	# Целевое вращение
	var target_rotation = Vector3(deg_to_rad(target_angle), 0, 0)
	
	# Анимируем все три двигателя
	tween.tween_property(side_engine_left, "rotation", target_rotation, ROTATION_DURATION)
	tween.tween_property(side_engine_right, "rotation", target_rotation, ROTATION_DURATION)
	tween.tween_property(engine_aft, "rotation", target_rotation, ROTATION_DURATION)
	
	# По завершении разблокируем возможность поворота
	tween.finished.connect(func(): is_rotating = false)

func set_engines_rotation(angle: float):
	var rotation_vec = Vector3(deg_to_rad(angle), 0, 0)
	side_engine_left.rotation = rotation_vec
	side_engine_right.rotation = rotation_vec
	engine_aft.rotation = rotation_vec
