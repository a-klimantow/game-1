class_name GunshotFx
extends Node3D
## Эффекты выстрела: вспышка и свет у дула, пороховой дым,
## след пули и искры в точке попадания.

## Мягкое круглое пятно для дыма, одно на всю игру.
static var _smoke_texture: GradientTexture2D


static func spawn(parent: Node, muzzle: Vector3, hit: Vector3, hit_something: bool) -> void:
	var fx := GunshotFx.new()
	parent.add_child(fx)
	fx.global_position = muzzle
	fx._play(muzzle, hit, hit_something)


func _play(muzzle: Vector3, hit: Vector3, hit_something: bool) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_flash()
	var dir := muzzle.direction_to(hit) if muzzle.distance_to(hit) > 0.05 else Vector3.FORWARD
	_smoke(Vector3(dir.x, 0.0, dir.z).normalized())
	_tracer(muzzle, hit)
	if hit_something:
		Debris.burst(get_parent(), hit, Color(1.0, 0.75, 0.3), 4)
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(queue_free)


func _flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 8.0
	light.omni_range = 5.0
	add_child(light)
	var material := _unshaded(Color(1.0, 0.8, 0.35, 0.95))
	var ball := _sphere(material, 0.07)
	add_child(ball)
	var tween := create_tween().set_parallel()
	tween.tween_property(light, "light_energy", 0.0, 0.12)
	tween.tween_property(ball, "scale", Vector3.ONE * 1.6, 0.08)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)


## Дымный порох: облако вылетает из дула вдоль выстрела, тормозит, расползается и
## медленно поднимается; у дула остаётся висеть клуб поменьше.
func _smoke(dir: Vector3) -> void:
	_smoke_cloud(dir, 6, 8.0, 2.0, 4.5, 1.4, Vector2(0.08, 0.8))
	_smoke_cloud(dir, 3, 30.0, 0.2, 0.8, 1.8, Vector2(0.06, 0.55))


func _smoke_cloud(
	dir: Vector3,
	amount: int,
	spread: float,
	speed_min: float,
	speed_max: float,
	lifetime: float,
	size: Vector2
) -> void:
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.amount = amount
	smoke.lifetime = lifetime
	smoke.randomness = 0.4
	smoke.mesh = _smoke_mesh()
	smoke.direction = dir
	smoke.spread = spread
	smoke.initial_velocity_min = speed_min
	smoke.initial_velocity_max = speed_max
	# Сильное торможение воздухом — облако «встаёт» в паре метров от дула.
	smoke.damping_min = 5.0
	smoke.damping_max = 8.0
	smoke.gravity = Vector3(0.0, 0.35, 0.0)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.angular_velocity_min = -25.0
	smoke.angular_velocity_max = 25.0
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, size.x / size.y))
	grow.add_point(Vector2(0.3, 0.3))
	grow.add_point(Vector2(1.0, 1.0), 0.5)
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
	fade.colors = PackedColorArray(
		[
			Color(1.0, 0.95, 0.85, 0.0),
			Color(0.85, 0.84, 0.8, 0.22),
			Color(0.72, 0.72, 0.7, 0.1),
			Color(0.65, 0.65, 0.65, 0.0),
		]
	)
	smoke.color_ramp = fade
	(smoke.mesh as QuadMesh).size = Vector2.ONE * size.y
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	smoke.emitting = true


## Плоский квадрат с мягким круглым пятном, всегда смотрит в камеру.
func _smoke_mesh() -> QuadMesh:
	if _smoke_texture == null:
		var falloff := Gradient.new()
		falloff.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		falloff.colors = PackedColorArray(
			[Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)]
		)
		_smoke_texture = GradientTexture2D.new()
		_smoke_texture.gradient = falloff
		_smoke_texture.fill = GradientTexture2D.FILL_RADIAL
		_smoke_texture.fill_from = Vector2(0.5, 0.5)
		_smoke_texture.fill_to = Vector2(1.0, 0.5)
		_smoke_texture.width = 64
		_smoke_texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _smoke_texture
	var mesh := QuadMesh.new()
	mesh.material = material
	return mesh


func _tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var material := _unshaded(Color(1.0, 0.9, 0.6, 0.8))
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = 0.015
	mesh.height = length
	mesh.material = material
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	# Ось цилиндра (Y) — вдоль полёта пули.
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	tracer.global_basis = Basis(side, dir, side.cross(dir))
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.12)


func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material


func _sphere(material: Material, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
