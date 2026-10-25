class_name Player
extends CharacterBody3D
## Серёга: ходьба, комбо мечом, блок, рывок и бросок пороховой бомбы.
##
## Управление (клавиатура / геймпад Xbox): WASD / левый стик — движение,
## ЛКМ / X, RB — удар, ПКМ / LT, LB (удерживать) — блок, Пробел / A — рывок, Q / Y — бомба.
## С мышью удары и броски летят в курсор, с геймпадом — по правому стику
## (или по направлению движения) с мягким автонаведением на ближайшего врага.

enum State { NORMAL, ATTACK, BLOCK, DASH, THROW }

# Idle и ходьба временные: настоящие появятся с Universal Animation Library (часть 1).
const ANIM_IDLE: StringName = &"Idle_FoldArms"
const ANIM_MOVE: StringName = &"Walk_Carry"
const ANIM_BLOCK: StringName = &"Sword_Block"
const ANIM_DASH: StringName = &"Slide_Start"
const ANIM_THROW: StringName = &"OverhandThrow"
const COMBO: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"]
const COMBO_DAMAGE: Array[int] = [10, 12, 25]
const COMBO_KNOCKBACK: Array[float] = [3.0, 3.0, 7.0]

## Доли анимации удара, когда меч наносит урон (от, до).
const HIT_WINDOW := Vector2(0.25, 0.65)
## С какой доли анимации удара можно перейти к следующему удару комбо.
const COMBO_WINDOW: float = 0.5
## Через сколько секунд блок «замирает» в защитной стойке.
const BLOCK_HOLD_TIME: float = 0.35
const THROW_SPEED: float = 1.2
## Момент выпуска бомбы, в секундах анимации броска.
const THROW_RELEASE_TIME: float = 0.55

## Автонаведение для геймпада: дальность и ширина конуса (косинус угла ≈ 40°).
const AUTO_AIM_RANGE: float = 6.0
const AUTO_AIM_MIN_DOT: float = 0.77
## Куда летит бомба с геймпада, если врага рядом нет.
const GAMEPAD_THROW_DISTANCE: float = 7.0

@export var move_speed: float = 5.0
@export var turn_speed: float = 14.0
@export var dash_speed: float = 13.0
@export var dash_time: float = 0.28
@export var dash_cooldown: float = 0.7
@export var throw_range: float = 12.0
@export var camera: TopDownCamera
@export var sword_scene: PackedScene
@export var bomb_scene: PackedScene

var state: State = State.NORMAL
## Для автотестов и катсцен: если задано, герой целится сюда, а не в курсор.
var aim_point_override: Vector3 = Vector3.INF

var _state_time: float = 0.0
var _combo_index: int = 0
var _combo_queued: bool = false
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_cooldown_left: float = 0.0
var _bomb_thrown: bool = false
var _throw_target: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model: CharacterModel = $Model
@onready var attack_area: Hitbox = $Model/AttackArea


func _ready() -> void:
	if sword_scene:
		model.attach_to_bone(sword_scene.instantiate() as Node3D, &"hand_r")
	model.play(ANIM_IDLE, 0.0)


func is_blocking() -> bool:
	return state == State.BLOCK


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	match state:
		State.NORMAL:
			_update_normal(delta)
		State.ATTACK:
			_update_attack()
		State.BLOCK:
			_update_block(delta)
		State.DASH:
			_update_dash()
		State.THROW:
			_update_throw()

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


# --- Состояния ---------------------------------------------------------------


func _update_normal(delta: float) -> void:
	var dir := _input_direction()
	_set_horizontal_velocity(dir * move_speed)
	if dir != Vector3.ZERO:
		_face(dir, delta)
		model.play(ANIM_MOVE)
	else:
		model.play(ANIM_IDLE)

	if Input.is_action_just_pressed(&"attack"):
		_start_attack(0)
	elif Input.is_action_pressed(&"block"):
		_change_state(State.BLOCK)
		model.play(ANIM_BLOCK, 0.1, 1.0, true)
	elif Input.is_action_just_pressed(&"dash") and _dash_cooldown_left <= 0.0:
		_start_dash(dir)
	elif Input.is_action_just_pressed(&"throw") and bomb_scene:
		_start_throw()


func _start_attack(index: int) -> void:
	_change_state(State.ATTACK)
	_combo_index = index
	_combo_queued = false
	attack_area.active = false
	attack_area.damage = COMBO_DAMAGE[index]
	attack_area.knockback = COMBO_KNOCKBACK[index]
	_face_instant(_aim_direction())
	model.play(COMBO[index], 0.08, 1.0, true)


func _update_attack() -> void:
	_set_horizontal_velocity(Vector3.ZERO)
	var progress := _state_time / model.get_animation_length(COMBO[_combo_index])
	attack_area.active = progress >= HIT_WINDOW.x and progress <= HIT_WINDOW.y

	if Input.is_action_just_pressed(&"attack"):
		_combo_queued = true
	var has_next := _combo_index < COMBO.size() - 1
	if _combo_queued and has_next and progress >= COMBO_WINDOW:
		_start_attack(_combo_index + 1)
	elif progress >= 1.0:
		_change_state(State.NORMAL)


func _update_block(delta: float) -> void:
	_set_horizontal_velocity(Vector3.ZERO)
	_face(_aim_direction(), delta)
	if _state_time >= BLOCK_HOLD_TIME and model.is_playing():
		model.pause()
	if not Input.is_action_pressed(&"block"):
		_change_state(State.NORMAL)


func _start_dash(input_dir: Vector3) -> void:
	_dash_dir = input_dir if input_dir != Vector3.ZERO else _facing()
	_dash_cooldown_left = dash_cooldown
	_face_instant(_dash_dir)
	_change_state(State.DASH)
	model.play(ANIM_DASH, 0.05, 1.3, true)


func _update_dash() -> void:
	_set_horizontal_velocity(_dash_dir * dash_speed)
	if _state_time >= dash_time:
		_change_state(State.NORMAL)


func _start_throw() -> void:
	var offset := _aim_point() - global_position
	offset.y = 0.0
	offset = offset.limit_length(throw_range)
	_throw_target = global_position + offset
	_bomb_thrown = false
	_face_instant(offset)
	_change_state(State.THROW)
	model.play(ANIM_THROW, 0.1, THROW_SPEED, true)


func _update_throw() -> void:
	_set_horizontal_velocity(Vector3.ZERO)
	if not _bomb_thrown and _state_time >= THROW_RELEASE_TIME / THROW_SPEED:
		_bomb_thrown = true
		var bomb := bomb_scene.instantiate() as Bomb
		get_parent().add_child(bomb)
		bomb.launch(model.get_bone_global_position(&"hand_r"), _throw_target, 0.7)
	if _state_time >= 0.85 * model.get_animation_length(ANIM_THROW) / THROW_SPEED:
		_change_state(State.NORMAL)


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state != State.ATTACK:
		attack_area.active = false


# --- Помощники ---------------------------------------------------------------


func _input_direction() -> Vector3:
	return _camera_relative(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))


func _stick_aim_direction() -> Vector3:
	return _camera_relative(Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down"))


## Переводит ввод (стик/WASD) в направление на земле относительно камеры.
func _camera_relative(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera:
		right = Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
		forward = Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
	return (right * input.x - forward * input.y).limit_length(1.0)


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


## Куда смотрит модель (по горизонтали).
func _facing() -> Vector3:
	var z := model.global_basis.z
	return Vector3(z.x, 0.0, z.z).normalized()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(dir.x, dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _face_instant(dir: Vector3) -> void:
	if dir.length() >= 0.01:
		model.rotation.y = atan2(dir.x, dir.z)


func _aim_point() -> Vector3:
	if aim_point_override != Vector3.INF:
		return aim_point_override
	if InputDevice.is_gamepad():
		return _gamepad_aim_point()
	if camera:
		return camera.get_mouse_ground_point(global_position.y)
	return global_position + _facing()


## Прицел с геймпада: правый стик, иначе направление движения, иначе взгляд героя.
## Если в этом направлении рядом есть враг — целимся прямо в него.
func _gamepad_aim_point() -> Vector3:
	var dir := _stick_aim_direction()
	if dir == Vector3.ZERO:
		dir = _input_direction()
	if dir == Vector3.ZERO:
		dir = _facing()
	dir = dir.normalized()
	var enemy := _find_auto_aim_target(dir)
	if enemy:
		return enemy.global_position
	return global_position + dir * GAMEPAD_THROW_DISTANCE


func _find_auto_aim_target(dir: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := AUTO_AIM_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance < 0.01 or distance > best_distance:
			continue
		if to_enemy.normalized().dot(dir) < AUTO_AIM_MIN_DOT:
			continue
		best = enemy
		best_distance = distance
	return best


func _aim_direction() -> Vector3:
	var dir := _aim_point() - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.1 else _facing()
