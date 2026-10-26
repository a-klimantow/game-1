class_name Enemy
extends CharacterBody3D
## Общее для всех врагов: контратака героя и значок-подсказка над головой.
## Конкретный враг переопределяет is_counterable() и receive_counter().

## С какого расстояния до героя показывать значок контратаки.
const COUNTER_HINT_RANGE: float = 4.0
const COUNTER_HINT_COLOR := Color(1.0, 0.85, 0.2)

var _counter_hint: Label3D


## Можно ли сейчас контратаковать (обычно — во время замаха и взмаха).
func is_counterable() -> bool:
	return false


## Герой отвёл удар: враг должен прервать атаку и открыться.
func receive_counter(_from_position: Vector3) -> void:
	pass


## Создаёт значок контратаки над головой на высоте height.
func _setup_counter_hint(height: float) -> void:
	_counter_hint = Label3D.new()
	_counter_hint.position = Vector3(0.0, height, 0.0)
	_counter_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_counter_hint.no_depth_test = true
	_counter_hint.font_size = 64
	_counter_hint.outline_size = 14
	_counter_hint.pixel_size = 0.005
	_counter_hint.modulate = COUNTER_HINT_COLOR
	_counter_hint.outline_modulate = Color(0.25, 0.1, 0.0)
	_counter_hint.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_counter_hint.visible = false
	add_child(_counter_hint)


## Показывает значок, пока врага можно контратаковать и герой рядом.
func _update_counter_hint(target: Node3D) -> void:
	if _counter_hint == null:
		return
	var near := (
		target != null and target.global_position.distance_to(global_position) <= COUNTER_HINT_RANGE
	)
	var show := is_counterable() and near
	if show and not _counter_hint.visible:
		_counter_hint.text = "! %s" % ("LB" if InputDevice.is_gamepad() else "F")
		_counter_hint.scale = Vector3.ONE * 0.3
		_counter_hint.visible = true
		var tween := _counter_hint.create_tween()
		(
			tween
			. tween_property(_counter_hint, "scale", Vector3.ONE, 0.15)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	elif not show:
		_counter_hint.visible = false
