extends Node3D
class_name OrbitalParticleEffect

# === НАСТРОЙКИ ===
@export var effect_enabled: bool = true  # 🔥 Включить/выключить эффект

@export_group("Orbit Settings")
@export var orbit_radius: float = 2.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 1.0

@export_group("Visual Style")
@export_enum("Energy Blade", "Hologram Cube", "Neon Ring", "Data Stream") var visual_style: int = 0
@export var particle_color: Color = Color(0.0, 1.0, 0.8, 0.9)
@export var particle_size: float = 0.3
@export var trail_length: int = 20

@export_group("Visual Effects")
@export var glow_intensity: float = 2.5
@export var pulse_speed: float = 3.0

# === СОСТОЯНИЕ ===
var is_active: bool = false
var current_angle: float = 0.0
var player_ref: Node3D = null

# === ВИЗУАЛЬНЫЕ КОМПОНЕНТЫ ===
var particle_mesh_instance: MeshInstance3D
var trail_points: Array[Vector3] = []
var trail_mesh: ImmediateMesh
var trail_mesh_instance: MeshInstance3D
var particle_material: ShaderMaterial

# ============================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================
func _ready():
	visible = false
	if effect_enabled:
		_create_particle()
		_create_trail()

func _create_particle():
	particle_mesh_instance = MeshInstance3D.new()
	add_child(particle_mesh_instance)
	
	# Выбираем меш в зависимости от стиля
	match visual_style:
		0: # Energy Blade (энергетический клинок)
			var box = BoxMesh.new()
			box.size = Vector3(0.15, 0.6, 0.05)
			particle_mesh_instance.mesh = box
			
		1: # Hologram Cube (голографический куб)
			var box = BoxMesh.new()
			box.size = Vector3(particle_size, particle_size, particle_size)
			particle_mesh_instance.mesh = box
			particle_mesh_instance.rotation_degrees = Vector3(45, 45, 0)
			
		2: # Neon Ring (неоновое кольцо)
			var torus = TorusMesh.new()
			torus.inner_radius = particle_size * 0.6
			torus.outer_radius = particle_size * 0.8
			torus.rings = 32
			torus.ring_segments = 32
			particle_mesh_instance.mesh = torus
			particle_mesh_instance.rotation_degrees = Vector3(90, 0, 0)
			
		3: # Data Stream (поток данных - вытянутый цилиндр)
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.08
			cylinder.bottom_radius = 0.08
			cylinder.height = 0.8
			cylinder.radial_segments = 8
			particle_mesh_instance.mesh = cylinder
	
	# Sci-fi шейдер
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec3 base_color : source_color = vec3(0.0, 1.0, 0.8);
uniform float time_param;
uniform float glow_intensity = 2.5;
uniform float pulse_speed = 3.0;
uniform int visual_style = 0;

void fragment() {
	// Базовая пульсация
	float pulse = sin(time_param * pulse_speed) * 0.5 + 0.5;
	
	// Разные паттерны для разных стилей
	float pattern = 1.0;
	
	if (visual_style == 0) {
		// Energy Blade - вертикальные энергетические волны
		pattern = sin(UV.y * 20.0 - time_param * 5.0) * 0.5 + 0.5;
		pattern = pow(pattern, 2.0);
	}
	else if (visual_style == 1) {
		// Hologram Cube - сетка
		float grid = max(
			sin(UV.x * 30.0 + time_param * 3.0),
			sin(UV.y * 30.0 + time_param * 3.0)
		) * 0.5 + 0.5;
		pattern = grid;
	}
	else if (visual_style == 2) {
		// Neon Ring - вращающиеся лучи
		float angle = atan(UV.y - 0.5, UV.x - 0.5);
		pattern = abs(sin(angle * 8.0 + time_param * 4.0));
	}
	else if (visual_style == 3) {
		// Data Stream - восходящие данные
		float stream = sin(UV.y * 15.0 - time_param * 8.0) * 0.5 + 0.5;
		float noise = fract(sin(UV.x * 50.0 + time_param) * 43758.5453);
		pattern = stream * noise;
	}
	
	// Градиент прозрачности от центра
	vec2 center = UV * 2.0 - 1.0;
	float dist = length(center);
	float fade = 1.0 - smoothstep(0.3, 1.0, dist);
	
	ALBEDO = base_color;
	EMISSION = base_color * (glow_intensity + pulse * 0.8 + pattern * 0.5);
	ALPHA = (fade * 0.7 + pattern * 0.3) * (0.8 + pulse * 0.2);
}
"""
	particle_material = ShaderMaterial.new()
	particle_material.shader = shader
	particle_material.set_shader_parameter("base_color", Vector3(particle_color.r, particle_color.g, particle_color.b))
	particle_material.set_shader_parameter("glow_intensity", glow_intensity)
	particle_material.set_shader_parameter("pulse_speed", pulse_speed)
	particle_material.set_shader_parameter("visual_style", visual_style)
	
	particle_mesh_instance.material_override = particle_material

func _create_trail():
	trail_mesh_instance = MeshInstance3D.new()
	add_child(trail_mesh_instance)
	
	trail_mesh = ImmediateMesh.new()
	trail_mesh_instance.mesh = trail_mesh
	
	var trail_shader = Shader.new()
	trail_shader.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.0, 1.0, 0.8);

void fragment() {
	// Пульсирующий хвост с точками данных
	float pattern = sin(UV.x * 30.0 - TIME * 5.0) * 0.5 + 0.5;
	
	ALBEDO = base_color;
	EMISSION = base_color * (1.2 + pattern * 0.8);
	ALPHA = COLOR.a * (0.5 + pattern * 0.2);
}
"""
	var trail_material = ShaderMaterial.new()
	trail_material.shader = trail_shader
	trail_material.set_shader_parameter("base_color", Vector3(particle_color.r, particle_color.g, particle_color.b))
	trail_mesh_instance.material_override = trail_material

# ============================================
# ОСНОВНЫЕ МЕТОДЫ
# ============================================
func set_player_reference(player: Node3D) -> void:
	player_ref = player

func activate() -> void:
	if not effect_enabled:
		return
		
	if not player_ref:
		push_warning("⚠️ OrbitalParticleEffect: Нет референса игрока!")
		return
	
	is_active = true
	visible = true
	trail_points.clear()
	print("✨ Орбитальные частицы: активированы (стиль: %d)" % visual_style)

func deactivate() -> void:
	is_active = false
	visible = false
	trail_points.clear()

# ============================================
# ОБНОВЛЕНИЕ
# ============================================
func _process(delta: float):
	if not is_active or not player_ref or not effect_enabled:
		return
	
	current_angle += delta * orbit_speed * TAU
	
	var offset = Vector3(
		cos(current_angle) * orbit_radius,
		orbit_height,
		sin(current_angle) * orbit_radius
	)
	
	var particle_world_pos = player_ref.global_position + offset
	particle_mesh_instance.global_position = particle_world_pos
	
	# Вращение самой частицы для визуального эффекта
	if visual_style == 1: # Cube вращается
		particle_mesh_instance.rotation.y += delta * 2.0
		particle_mesh_instance.rotation.x += delta * 1.5
	elif visual_style == 0: # Blade вращается вокруг направления движения
		particle_mesh_instance.rotation.z += delta * 3.0
	
	if particle_material:
		particle_material.set_shader_parameter("time_param", Time.get_ticks_msec() / 1000.0)
	
	_update_trail(particle_world_pos)

func _update_trail(current_pos: Vector3):
	trail_points.push_front(current_pos)
	
	if trail_points.size() > trail_length:
		trail_points.resize(trail_length)
	
	_draw_trail()

func _draw_trail():
	if trail_points.size() < 2:
		return
	
	trail_mesh.clear_surfaces()
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	var trail_width = particle_size * 0.4
	
	for i in trail_points.size():
		var point = trail_points[i]
		var alpha = 1.0 - (float(i) / trail_length)
		
		# Делаем хвост более динамичным - изменяем ширину
		var width_multiplier = 1.0 - (float(i) / trail_length) * 0.7
		var up = Vector3.UP
		var side = up * trail_width * alpha * width_multiplier
		
		trail_mesh.surface_set_color(Color(particle_color.r, particle_color.g, particle_color.b, alpha * 0.8))
		trail_mesh.surface_add_vertex(point + side)
		
		trail_mesh.surface_set_color(Color(particle_color.r, particle_color.g, particle_color.b, alpha * 0.8))
		trail_mesh.surface_add_vertex(point - side)
	
	trail_mesh.surface_end()

# ============================================
# ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ
# ============================================
func set_orbit_speed(speed: float) -> void:
	orbit_speed = speed

func set_orbit_radius(radius: float) -> void:
	orbit_radius = radius

func set_particle_color(color: Color) -> void:
	particle_color = color
	if particle_material:
		particle_material.set_shader_parameter("base_color", Vector3(color.r, color.g, color.b))

func change_visual_style(new_style: int) -> void:
	visual_style = new_style
	if particle_mesh_instance:
		particle_mesh_instance.queue_free()
	_create_particle()
	print("🎨 Стиль изменён на: %d" % visual_style)
