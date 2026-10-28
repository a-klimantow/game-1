class_name TargetLock
extends Node
## Захват цели: кнопка захвата выбирает врага (ближайшего в стороне прицела),
## колёсико мыши или рывок правого стика переключает на соседнего.
## Пока цель захвачена, герой бьёт и стреляет в неё, а над ней висит метка.
## Захват снимается, если враг погиб, исчез или ушёл слишком далеко.

signal target_changed(target: Enemy)

## Дальность, в которой можно захватить цель.
const LOCK_RANGE: float = 15.0
## Цель дальше этого — захват снимается.
const BREAK_RANGE: float = 20.0
## Насколько надо отклонить правый стик, чтобы сменить цель.
const STICK_SWITCH_THRESHOLD: float = 0.7
const MARKER_COLOR := Color(1.0, 0.55, 0.15, 0.9)

var target: Enemy

var _player: Player
var _marker: Node3D
var _arrow: Node3D
## Стик вернулся в центр — можно переключать снова (один рывок = одна смена).
var _stick_ready: bool = true


func setup(player: Player) -> void:
	_player = player
	_build_marker()


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if Input.is_action_just_pressed(&"lock_on"):
		if target:
			_set_target(null)
		else:
			_set_target(_pick_initial())
	if target and not _is_valid(target):
		_set_target(null)
	if target:
		_update_stick_switch()


func _process(_delta: float) -> void:
	if target == null:
		return
	var at := target.get_global_transform_interpolated().origin
	_marker.global_position = at + Vector3.UP * 0.05
	_marker.rotate_y(0.03)
	_arrow.position.y = 2.7 + sin(Time.get_ticks_msec() * 0.006) * 0.08


## Колёсико мыши — следующая / предыдущая цель (по удалённости).
func _unhandled_input(event: InputEvent) -> void:
	if target == null:
		return
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_cycle(1)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_cycle(-1)


# --- Выбор цели --------------------------------------------------------------


func _candidates(max_range: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy and _distance(enemy) <= max_range:
			result.append(enemy)
	return result


## Первая цель: ближайшая, с предпочтением тех, что в стороне прицела.
func _pick_initial() -> Enemy:
	var aim := _player.get_aim_direction()
	var best: Enemy = null
	var best_score := INF
	for enemy: Enemy in _candidates(LOCK_RANGE):
		var to_enemy := _flat(enemy.global_position - _player.global_position)
		# Враг прямо по прицелу «ближе» на 4 м, позади — «дальше» на 4 м.
		var score := to_enemy.length() - to_enemy.normalized().dot(aim) * 4.0
		if score < best_score:
			best = enemy
			best_score = score
	return best


## Рывок правого стика: ближайший враг в эту сторону от текущей цели.
func _update_stick_switch() -> void:
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick.length() < 0.3:
		_stick_ready = true
		return
	if not _stick_ready or stick.length() < STICK_SWITCH_THRESHOLD:
		return
	_stick_ready = false
	var dir := _player.camera_relative(stick).normalized()
	var best: Enemy = null
	var best_distance := INF
	for enemy: Enemy in _candidates(LOCK_RANGE):
		if enemy == target:
			continue
		var offset := _flat(enemy.global_position - target.global_position)
		if offset.normalized().dot(dir) < 0.3:
			continue
		if offset.length() < best_distance:
			best = enemy
			best_distance = offset.length()
	if best:
		_set_target(best)


## Колёсико: следующая по удалённости цель, по кругу.
func _cycle(step: int) -> void:
	var list := _candidates(LOCK_RANGE)
	if list.size() < 2:
		return
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _distance(a) < _distance(b))
	var index := list.find(target)
	_set_target(list[posmod(index + step, list.size())])


func _set_target(enemy: Enemy) -> void:
	if enemy == target:
		return
	target = enemy
	_marker.visible = target != null
	if target:
		_marker.global_position = target.global_position
		_marker.reset_physics_interpolation()
	target_changed.emit(target)


func _is_valid(enemy: Enemy) -> bool:
	return (
		is_instance_valid(enemy)
		and enemy.is_inside_tree()
		and enemy.is_in_group(&"enemies")
		and _distance(enemy) <= BREAK_RANGE
	)


func _distance(enemy: Enemy) -> float:
	return _flat(enemy.global_position - _player.global_position).length()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Метка над целью ---------------------------------------------------------


## Кольцо на земле под целью и стрелка над головой.
func _build_marker() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = MARKER_COLOR
	material.no_depth_test = true

	_marker = Node3D.new()
	_marker.name = "TargetMarker"
	_marker.visible = false
	_marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_player.get_parent().add_child.call_deferred(_marker)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.7
	ring_mesh.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(ring)

	var arrow_mesh := CylinderMesh.new()
	arrow_mesh.top_radius = 0.12
	arrow_mesh.bottom_radius = 0.0
	arrow_mesh.height = 0.25
	arrow_mesh.material = material
	var arrow := MeshInstance3D.new()
	arrow.mesh = arrow_mesh
	arrow.position.y = 2.7
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(arrow)
	_arrow = arrow
