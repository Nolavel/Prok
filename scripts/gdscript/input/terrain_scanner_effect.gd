extends Node3D
class_name TerrainScannerEffect

# ============================================
# AAA-LEVEL TERRAIN SCANNER SYSTEM
# ============================================
# Профессиональная архитектура:
# 1. Несколько концентрических колец (wave system)
# 2. Частицы на фронте волны
# 3. Декали на земле
# 4. Звуковая обратная связь
# 5. Детекция объектов (опционально)

# === CORE SETTINGS ===
@export var effect_enabled: bool = true

@export_group("Scanner Behavior")
@export var max_radius: float = 20.0
@export var expansion_speed: float = 8.0
@export var scan_height: float = 0.3
@export var loop_delay: float = 1.5
@export var auto_loop: bool = true

@export_group("Visual Quality")
@export_range(1, 5) var wave_count: int = 3  # Количество концентрических волн
@export var wave_spacing: float = 2.5  # Расстояние между волнами
@export var primary_color: Color = Color(0.0, 0.9, 1.0, 1.0)
@export var secondary_color: Color = Color(0.0, 0.5, 0.8, 0.6)
@export var ring_thickness: float = 0.12

@export_group("Advanced Effects")
@export var enable_ground_ripples: bool = true
@export var enable_edge_particles: bool = true
@export var pulse_intensity: float = 1.0
@export var distortion_strength: float = 0.15

@export_group("Audio")
@export var scan_start_sound: AudioStream
@export var scan_loop_sound: AudioStream

# === STATE MANAGEMENT ===
enum ScanState { IDLE, STARTING, SCANNING, FADING, COOLDOWN }
var current_state: ScanState = ScanState.IDLE
var state_time: float = 0.0

var is_active: bool = false
var current_radius: float = 0.0
var player_ref: Node3D = null

# === VISUAL COMPONENTS ===
var wave_rings: Array[MeshInstance3D] = []
var wave_materials: Array[ShaderMaterial] = []
var ground_decal: MeshInstance3D
var particles_instance: GPUParticles3D
var audio_player: AudioStreamPlayer3D

# === PERFORMANCE ===
var last_scan_time: float = 0.0
const MIN_SCAN_INTERVAL: float = 0.5

# ============================================
# INITIALIZATION
# ============================================
func _ready():
	visible = false
	if effect_enabled:
		_create_wave_system()
		_create_ground_decal()
		_create_edge_particles()
		_create_audio_player()

func _create_wave_system():
	"""Создаём многослойную систему волн"""
	for i in wave_count:
		var ring = MeshInstance3D.new()
		add_child(ring)
		
		var torus = TorusMesh.new()
		torus.inner_radius = 1.0 - ring_thickness
		torus.outer_radius = 1.0 + ring_thickness
		torus.rings = 64
		torus.ring_segments = 64
		ring.mesh = torus
		ring.rotation_degrees = Vector3(0, 0, 0)  # 🔥 ИСПРАВЛЕНО: Параллельно земле (XZ)
		
		# Создаём уникальный материал для каждой волны
		var material = _create_wave_material(i)
		ring.material_override = material
		ring.scale = Vector3.ZERO
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		wave_rings.append(ring)
		wave_materials.append(material)

func _create_wave_material(wave_index: int) -> ShaderMaterial:
	"""AAA шейдер с многослойными эффектами"""
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;

uniform vec3 primary_color : source_color = vec3(0.0, 0.9, 1.0);
uniform vec3 secondary_color : source_color = vec3(0.0, 0.5, 0.8);
uniform float time_param;
uniform float scan_progress = 0.0;
uniform float pulse_intensity = 1.0;
uniform float wave_offset = 0.0;
uniform float distortion = 0.15;

// Noise function для процедурных паттернов
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    
    // === 1. FRESNEL EFFECT (edge glow) ===
    float fresnel = pow(1.0 - dist, 3.0);
    
    // === 2. SCANNING RAYS (hexagonal pattern) ===
    float angle = atan(uv.y, uv.x);
    float rays = abs(sin(angle * 6.0 + time_param * 2.0 + wave_offset));
    rays = pow(rays, 4.0);
    
    // === 3. TRAVELING WAVES ===
    float wave_pattern = sin(dist * 30.0 - time_param * 8.0 + wave_offset * 3.0);
    wave_pattern = wave_pattern * 0.5 + 0.5;
    
    // === 4. PROCEDURAL NOISE (tech pattern) ===
    vec2 noise_uv = uv * 10.0 + vec2(time_param * 0.5);
    float tech_noise = noise(noise_uv);
    tech_noise = step(0.6, tech_noise);
    
    // === 5. SCAN FRONT INTENSITY (leading edge) ===
    float edge_intensity = 1.0 - smoothstep(0.0, 0.15, scan_progress);
    edge_intensity = pow(edge_intensity, 2.0) * 3.0;
    
    // === 6. FADE OUT (tail) ===
    float fade = 1.0 - smoothstep(0.4, 1.0, scan_progress);
    
    // === 7. DISTORTION (энергетические искажения) ===
    float distort = sin(dist * 20.0 + time_param * 3.0) * distortion;
    
    // === FINAL COMPOSITION ===
    vec3 color_mix = mix(secondary_color, primary_color, fresnel);
    
    float pattern = rays * 0.4 + wave_pattern * 0.3 + tech_noise * 0.2 + fresnel * 0.8;
    pattern += edge_intensity;
    pattern *= pulse_intensity;
    
    ALBEDO = color_mix;
    EMISSION = color_mix * pattern * (2.0 + distort);
    ALPHA = (pattern * 0.5 + edge_intensity * 0.5) * fade * (0.6 + fresnel * 0.4);
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("primary_color", Vector3(primary_color.r, primary_color.g, primary_color.b))
	material.set_shader_parameter("secondary_color", Vector3(secondary_color.r, secondary_color.g, secondary_color.b))
	material.set_shader_parameter("pulse_intensity", pulse_intensity)
	material.set_shader_parameter("wave_offset", wave_index * 0.5)
	material.set_shader_parameter("distortion", distortion_strength)
	
	return material

func _create_ground_decal():
	"""Декаль на земле для дополнительного эффекта"""
	if not enable_ground_ripples:
		return
		
	ground_decal = MeshInstance3D.new()
	add_child(ground_decal)
	
	var plane = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	ground_decal.mesh = plane
	ground_decal.rotation_degrees = Vector3(0, 0, 0)  # 🔥 ИСПРАВЛЕНО: Параллельно земле (XZ)
	ground_decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(0.0, 0.9, 1.0);
uniform float time_param;
uniform float scan_progress = 0.0;

float circles(vec2 uv, float time) {
    float dist = length(uv);
    float ring = sin(dist * 15.0 - time * 5.0) * 0.5 + 0.5;
    return ring * (1.0 - smoothstep(0.0, 1.0, dist));
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float pattern = circles(uv * scan_progress, time_param);
    
    ALBEDO = color;
    EMISSION = color * pattern * 2.0;
    ALPHA = pattern * 0.3 * (1.0 - scan_progress * 0.5);
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("color", Vector3(primary_color.r, primary_color.g, primary_color.b))
	ground_decal.material_override = material

func _create_edge_particles():
	"""Частицы на фронте сканирующей волны"""
	if not enable_edge_particles:
		return
		
	particles_instance = GPUParticles3D.new()
	add_child(particles_instance)
	
	particles_instance.amount = 32
	particles_instance.lifetime = 1.0
	particles_instance.emitting = false
	particles_instance.one_shot = false
	
	# TODO: Настроить ParticleProcessMaterial для искр на фронте волны

func _create_audio_player():
	"""3D звук для сканера"""
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.max_distance = 50.0
	audio_player.unit_size = 5.0

# ============================================
# STATE MACHINE
# ============================================
func activate() -> void:
	if not effect_enabled:
		return
		
	if not player_ref:
		push_warning("⚠️ TerrainScannerEffect: Нет референса игрока!")
		return
	
	# Защита от спама
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_scan_time < MIN_SCAN_INTERVAL:
		return
	
	last_scan_time = current_time
	is_active = true
	visible = true
	_change_state(ScanState.STARTING)
	
	# Звук начала сканирования
	if scan_start_sound and audio_player:
		audio_player.stream = scan_start_sound
		audio_player.play()
	
	print("🔍 Сканер местности: активирован (AAA режим)")

func deactivate() -> void:
	is_active = false
	visible = false
	_change_state(ScanState.IDLE)
	current_radius = 0.0
	
	for ring in wave_rings:
		ring.scale = Vector3.ZERO
	
	if particles_instance:
		particles_instance.emitting = false
	
	print("🔍 Сканер местности: деактивирован")

func _change_state(new_state: ScanState) -> void:
	current_state = new_state
	state_time = 0.0

# ============================================
# UPDATE LOOP
# ============================================
func _process(delta: float):
	if not is_active or not player_ref or not effect_enabled:
		return
	
	state_time += delta
	
	# Обновляем позицию
	global_position = player_ref.global_position + Vector3(0, scan_height, 0)
	
	# Обновляем шейдеры
	var time = Time.get_ticks_msec() / 1000.0
	for material in wave_materials:
		material.set_shader_parameter("time_param", time)
		material.set_shader_parameter("pulse_intensity", pulse_intensity)
	
	if ground_decal and ground_decal.material_override:
		ground_decal.material_override.set_shader_parameter("time_param", time)
	
	# State machine
	match current_state:
		ScanState.STARTING:
			_update_starting(delta)
		ScanState.SCANNING:
			_update_scanning(delta)
		ScanState.FADING:
			_update_fading(delta)
		ScanState.COOLDOWN:
			_update_cooldown(delta)

func _update_starting(delta: float) -> void:
	"""Начальная фаза - быстрое появление первой волны"""
	if state_time > 0.1:
		_change_state(ScanState.SCANNING)
		current_radius = 0.0

func _update_scanning(delta: float) -> void:
	"""Основная фаза сканирования"""
	current_radius += delta * expansion_speed
	var progress = clamp(current_radius / max_radius, 0.0, 1.0)
	
	# Обновляем каждую волну с задержкой
	for i in wave_count:
		var wave_delay = i * wave_spacing / expansion_speed
		var wave_progress = clamp((state_time - wave_delay) / (max_radius / expansion_speed), 0.0, 1.0)
		var wave_radius = wave_progress * max_radius
		
		if wave_progress > 0.0 and wave_progress < 1.0:
			wave_rings[i].scale = Vector3(wave_radius, 1.0, wave_radius)
			wave_materials[i].set_shader_parameter("scan_progress", wave_progress)
			wave_rings[i].visible = true
		else:
			wave_rings[i].visible = false
	
	# Обновляем декаль на земле
	if ground_decal and ground_decal.material_override:
		ground_decal.scale = Vector3(current_radius, 1.0, current_radius)
		ground_decal.position.y = -scan_height + 0.01  # Чуть над землёй
		ground_decal.material_override.set_shader_parameter("scan_progress", progress)
	
	# Частицы на фронте волны
	if particles_instance and enable_edge_particles:
		particles_instance.emitting = true
	
	# Переход к затуханию
	if current_radius >= max_radius:
		_change_state(ScanState.FADING)

func _update_fading(delta: float) -> void:
	"""Затухание после достижения максимума"""
	if state_time > 0.5:
		_change_state(ScanState.COOLDOWN)
		
		for ring in wave_rings:
			ring.visible = false
		
		if particles_instance:
			particles_instance.emitting = false

func _update_cooldown(delta: float) -> void:
	"""Задержка перед следующим сканом"""
	if state_time > loop_delay:
		if auto_loop and is_active:
			_change_state(ScanState.STARTING)
		else:
			deactivate()

# ============================================
# PUBLIC API
# ============================================
func set_player_reference(player: Node3D) -> void:
	player_ref = player

func trigger_single_scan() -> void:
	"""Запустить одиночное сканирование"""
	var old_loop = auto_loop
	auto_loop = false
	activate()
	auto_loop = old_loop

func set_scanner_color(color: Color) -> void:
	primary_color = color
	for material in wave_materials:
		material.set_shader_parameter("primary_color", Vector3(color.r, color.g, color.b))

func set_max_radius(radius: float) -> void:
	max_radius = radius

func set_expansion_speed(speed: float) -> void:
	expansion_speed = speed
