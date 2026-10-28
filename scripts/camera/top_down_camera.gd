class_name TopDownCamera
extends Camera3D
## Камера сверху под углом: плавно следует за целью, угол не меняется.

@export var target: Node3D
## Смещение камеры от цели. Наклон камеры получается из него автоматически.
@export var offset: Vector3 = Vector3(0.0, 11.0, 7.5)
@export var follow_speed: float = 6.0
## Насколько быстро затухает тряска (в единицах силы в секунду).
@export var shake_decay: float = 2.5
## Максимальное смещение картинки при тряске силой 1.0.
@export var shake_amount: float = 0.35

## Насколько подаваться к захваченной цели (доля расстояния) и не дальше скольких метров.
@export var focus_lean: float = 0.3
@export var focus_max_shift: float = 4.0

## Захваченная цель: камера подаётся в её сторону, чтобы и герой, и враг были в кадре.
var focus_target: Node3D

var _shake: float = 0.0


func _ready() -> void:
	# Камера двигается в _process сама, интерполяция физики ей не нужна.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target:
		global_position = target.global_position + offset
		look_at(target.global_position)


func _process(delta: float) -> void:
	if target == null:
		return
	var center := target.get_global_transform_interpolated().origin
	if focus_target and is_instance_valid(focus_target):
		var to_focus := focus_target.global_position - center
		to_focus.y = 0.0
		center += (to_focus * focus_lean).limit_length(focus_max_shift)
	var desired := center + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))

	_shake = move_toward(_shake, 0.0, shake_decay * delta)
	h_offset = randf_range(-1.0, 1.0) * _shake * _shake * shake_amount
	v_offset = randf_range(-1.0, 1.0) * _shake * _shake * shake_amount


## Трясёт камеру; strength от 0 до 1. Сильные толчки не перекрываются слабыми.
func shake(strength: float) -> void:
	_shake = maxf(_shake, clampf(strength, 0.0, 1.0))


## Точка на горизонтальной плоскости height под курсором мыши.
func get_mouse_ground_point(height: float = 0.0) -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(
		project_ray_origin(mouse), project_ray_normal(mouse)
	)
	if hit is Vector3:
		return hit
	return target.global_position if target else Vector3.ZERO
