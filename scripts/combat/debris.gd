class_name Debris
extends RigidBody3D
## Обломок: разлетается, падает и гаснет. Используется, когда ломается щит.

const LIFETIME: float = 2.5


## Разбрасывает count обломков из точки origin.
static func burst(parent: Node, origin: Vector3, color: Color, count: int = 7) -> void:
	for i: int in count:
		var piece := Debris.new()
		parent.add_child(piece)
		piece.global_position = (
			origin + Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
		)
		piece._setup(color)


func _setup(color: Color) -> void:
	collision_layer = 0
	collision_mask = 1  # только мир
	var size := Vector3(randf_range(0.08, 0.2), randf_range(0.03, 0.05), randf_range(0.1, 0.3))
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	reset_physics_interpolation()
	linear_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(2.5, 5.0), randf_range(-3.0, 3.0))
	angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))

	var tween := create_tween()
	tween.tween_interval(LIFETIME - 0.6)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
