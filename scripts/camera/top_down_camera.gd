class_name TopDownCamera
extends Camera3D
## Камера сверху под углом: плавно следует за целью, угол не меняется.

@export var target: Node3D
## Смещение камеры от цели. Наклон камеры получается из него автоматически.
@export var offset: Vector3 = Vector3(0.0, 11.0, 7.5)
@export var follow_speed: float = 6.0


func _ready() -> void:
	# Камера двигается в _process сама, интерполяция физики ей не нужна.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target:
		global_position = target.global_position + offset
		look_at(target.global_position)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.get_global_transform_interpolated().origin + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))


## Точка на горизонтальной плоскости height под курсором мыши.
func get_mouse_ground_point(height: float = 0.0) -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(
		project_ray_origin(mouse), project_ray_normal(mouse)
	)
	if hit is Vector3:
		return hit
	return target.global_position if target else Vector3.ZERO
