extends Node3D
class_name Weapon

@export_group("Basic Settings")
@export var weapon_name: String = "Weapon"
@export var muzzle_point: Node3D
@export var bullet_scene: PackedScene

# fire_mode: 0 = Single, 1 = Auto (стрельба каждые burst_delay пока держишь)
@export_enum("Single", "Burst") var fire_mode: int = 0
@export var burst_delay: float = 0.1

@export_group("Aim Offset")
@export var aim_offset: Vector2 = Vector2.ZERO

@export_group("Muzzle Offset")
@export var muzzle_offset: Vector3 = Vector3.ZERO

@export_group("Ballistics")
@export var use_spread: bool = true
@export var bullet_speed: float = 100.0
@export var bullet_gravity: float = 0.0
@export var spread_angle: float = 0.0
@export var damage: float = 25.0

@export_group("Recoil")
@export var recoil_x: float = 1.0
@export var recoil_y: float = 2.0
@export var recoil_randomness: float = 0.5
@export_enum("Light", "Medium", "Heavy") var recoil_type: int = 0
@export var recoil_recovery_speed: float = 8.0
@export var recoil_recovery_delay: float = 0.2

@export_group("Fire Rate")
@export var fire_rate: float = 600.0

@export_group("Ammo")
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 2.0

@export_group("Audio")
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream

# Runtime
var current_ammo: int
var fire_timer: float = 0.0
var is_reloading: bool = false

# Recoil
var accumulated_recoil: Vector2 = Vector2.ZERO
var recoil_recovery_timer: float = 0.0

# Refs
var audio_player: AudioStreamPlayer3D
var reload_timer: Timer

signal weapon_fired(weapon: Weapon)
signal ammo_changed(current: int, max: int)
signal reload_started
signal reload_finished

func _ready() -> void:
	current_ammo = magazine_size
	_setup_audio()
	_setup_reload_timer()
	ammo_changed.emit(current_ammo, magazine_size)

func _process(delta: float) -> void:
	fire_timer -= delta
	_update_recoil_recovery(delta)

	if Input.is_action_just_pressed("weapon_reload"):
		reload()

	if fire_mode == 0 and Input.is_action_just_pressed("shoot"):
		_try_fire_once()

	if fire_mode == 1 and Input.is_action_pressed("shoot"):
		_try_fire_auto()

	if current_ammo <= 0 and not is_reloading and reserve_ammo > 0:
		reload()

func _try_fire_once() -> void:
	if fire_timer > 0.0:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var target: Vector3 = _get_aim_target_from_camera(camera, aim_offset)
		fire(target)


func _try_fire_auto() -> void:
	if fire_timer <= 0.0:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var target: Vector3 = _get_aim_target_from_camera(camera, aim_offset)
			fire(target)

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.max_distance = 50.0

func _setup_reload_timer() -> void:
	reload_timer = Timer.new()
	add_child(reload_timer)
	reload_timer.wait_time = reload_time
	reload_timer.timeout.connect(_finish_reload)

func fire(target_pos: Vector3) -> bool:
	if not _can_fire():
		if current_ammo <= 0 and not is_reloading:
			_play_sound(empty_sound)
		return false
	_execute_fire(target_pos)
	return true

func _can_fire() -> bool:
	return current_ammo > 0 and not is_reloading and fire_timer <= 0.0

func _execute_fire(target_pos: Vector3) -> void:
	if not muzzle_point:
		printerr("❌ Нет MuzzlePoint в ", weapon_name)
		return
	if not bullet_scene:
		printerr("❌ Нет сцены пули в ", weapon_name)
		return

	var bullet: Node3D = bullet_scene.instantiate()
	if not bullet is Node3D:
		printerr("❌ Сцена пули должна быть Node3D!")
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		printerr("❌ Камера не найдена!")
		return
	var shoot_dir: Vector3 = (target_pos - camera.global_position).normalized()
	shoot_dir = _apply_spread(shoot_dir)

	get_tree().root.add_child(bullet)
	var muzzle_pos: Vector3 = muzzle_point.global_transform.origin + muzzle_point.global_transform.basis * muzzle_offset
	bullet.global_transform = Transform3D(Basis.looking_at(shoot_dir), muzzle_pos)



	if bullet is RigidBody3D:
		bullet.linear_velocity = shoot_dir * bullet_speed
		if bullet_gravity > 0.0:
			bullet.gravity_scale = bullet_gravity
	elif bullet.has_method("set_velocity"):
		bullet.set_velocity(shoot_dir * bullet_speed)

	if bullet.has_method("set_damage"):
		bullet.set_damage(damage)

	current_ammo -= 1
	fire_timer = (60.0 / max(fire_rate, 1.0)) if fire_mode == 0 else max(burst_delay, 0.01)


	_play_sound(fire_sound)
	weapon_fired.emit(self)
	ammo_changed.emit(current_ammo, magazine_size)

func _apply_spread(base_direction: Vector3) -> Vector3:
	if not use_spread or spread_angle <= 0.0:
		return base_direction
	var spread_rad: float = deg_to_rad(spread_angle)
	var random_angle: float = randf() * TAU
	var random_magnitude: float = randf() * spread_rad

	var up: Vector3 = Vector3.UP
	if abs(base_direction.dot(up)) > 0.9:
		up = Vector3.RIGHT

	var right: Vector3 = base_direction.cross(up).normalized()
	up = right.cross(base_direction).normalized()

	var spread_offset: Vector3 = (right * cos(random_angle) + up * sin(random_angle)) * random_magnitude
	return (base_direction + spread_offset).normalized()

func reload() -> bool:
	if is_reloading or current_ammo >= magazine_size or reserve_ammo <= 0:
		return false
	is_reloading = true
	_play_sound(reload_sound)
	reload_timer.start()
	reload_started.emit()
	return true

func _finish_reload() -> void:
	var ammo_needed: int = magazine_size - current_ammo
	var ammo_to_add: int = min(ammo_needed, reserve_ammo)
	current_ammo += ammo_to_add
	reserve_ammo -= ammo_to_add
	is_reloading = false
	ammo_changed.emit(current_ammo, magazine_size)
	reload_finished.emit()

func get_recoil() -> Vector2:
	if current_ammo <= 0:
		return Vector2.ZERO
	var base_recoil: Vector2 = Vector2(
		randf_range(-recoil_x, recoil_x) * recoil_randomness,
		recoil_y + randf_range(0, recoil_y * recoil_randomness)
	)
	accumulated_recoil += base_recoil
	recoil_recovery_timer = recoil_recovery_delay
	return base_recoil

func _update_recoil_recovery(delta: float) -> void:
	recoil_recovery_timer -= delta
	if recoil_recovery_timer <= 0.0:
		match recoil_type:
			0:
				accumulated_recoil = accumulated_recoil.lerp(Vector2.ZERO, recoil_recovery_speed * delta)
			1:
				accumulated_recoil = accumulated_recoil.lerp(Vector2.ZERO, recoil_recovery_speed * 0.6 * delta)
			2:
				pass

func get_total_recoil() -> Vector2:
	return accumulated_recoil

func reset_recoil() -> void:
	accumulated_recoil = Vector2.ZERO
	recoil_recovery_timer = 0.0

func _play_sound(sound: AudioStream) -> void:
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

func add_ammo(amount: int) -> void:
	reserve_ammo += amount

func get_ammo_info() -> Dictionary:
	return {
		"current": current_ammo,
		"magazine": magazine_size,
		"reserve": reserve_ammo,
		"is_reloading": is_reloading
	}

func reset_weapon() -> void:
	current_ammo = magazine_size
	reserve_ammo = magazine_size * 4
	is_reloading = false
	fire_timer = 0.0
	reset_recoil()
	ammo_changed.emit(current_ammo, magazine_size)

func _get_aim_target_from_camera(camera: Camera3D, offset: Vector2 = aim_offset) -> Vector3:
	var viewport_center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	viewport_center += offset
	var ray_length: float = 2000.0
	var ray_origin: Vector3 = camera.project_ray_origin(viewport_center)
	var ray_direction: Vector3 = camera.project_ray_normal(viewport_center)
	return ray_origin + ray_direction * ray_length
