class_name GunshotFx
extends Node3D
## Эффекты выстрела: вспышка и свет у дула, пороховой дым,
## след пули и искры в точке попадания.


static func spawn(parent: Node, muzzle: Vector3, hit: Vector3, hit_something: bool) -> void:
	var fx := GunshotFx.new()
	parent.add_child(fx)
	fx.global_position = muzzle
	fx._play(muzzle, hit, hit_something)


func _play(muzzle: Vector3, hit: Vector3, hit_something: bool) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_flash()
	_smoke()
	_tracer(muzzle, hit)
	if hit_something:
		Debris.burst(get_parent(), hit, Color(1.0, 0.75, 0.3), 4)
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)


func _flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 8.0
	light.omni_range = 5.0
	add_child(light)
	var material := _unshaded(Color(1.0, 0.8, 0.35, 0.95))
	var ball := _sphere(material, 0.12)
	add_child(ball)
	var tween := create_tween().set_parallel()
	tween.tween_property(light, "light_energy", 0.0, 0.12)
	tween.tween_property(ball, "scale", Vector3.ONE * 2.0, 0.08)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)


func _smoke() -> void:
	var material := _unshaded(Color(0.75, 0.75, 0.72, 0.55))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var puff := _sphere(material, 0.15)
	add_child(puff)
	var tween := create_tween().set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * 5.0, 1.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "position:y", 0.6, 1.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.4)


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
