class_name Possessed
extends Enemy
## «Одержимый» — крестьянин, задетый аномалией. Бредёт к герою, замахивается
## (наливается красным — это предупреждение) и бьёт двумя взмахами.
## После удара открыт для ответа. Попадания прерывают замах, но не сам взмах.
## Во время замаха и взмахов его можно контратаковать — тогда он надолго оглушён.

enum State { IDLE, CHASE, ATTACK, RECOVER, STAGGER, COUNTERED, DEAD }

const ANIM_IDLE: StringName = &"Zombie_Idle"
const ANIM_WALK: StringName = &"Zombie_Walk_Fwd"
const ANIM_ATTACK: StringName = &"Zombie_Scratch"
const ANIM_HIT_LIGHT: StringName = &"Hit_Chest"
const ANIM_HIT_HEAVY: StringName = &"Hit_Knockback"
const ANIM_DEATH: StringName = &"Death01"

## Скорость шага внутри анимации, м/с (измерено по root motion из UAL2_Standard_RM).
const WALK_ANIM_SPEED: float = 1.05
## Окна удара в Zombie_Scratch (доли анимации), посчитаны по траектории кисти.
const STRIKE_WINDOWS: Array[Vector2] = [Vector2(0.3, 0.44), Vector2(0.56, 0.7)]
## Окно контратаки (доли анимации удара): от начала замаха до конца второго взмаха.
const COUNTER_WINDOW := Vector2(0.1, 0.7)
const WARNING_COLOR := Color(1.0, 0.1, 0.05, 0.55)
const HIT_COLOR := Color(1.0, 1.0, 1.0, 0.6)
## Одержимые не толпятся в одной точке: отталкиваются друг от друга на этом расстоянии.
const SEPARATION_RADIUS: float = 1.3

@export_group("Поведение")
@export var aggro_range: float = 10.0
@export var lose_range: float = 16.0
@export var attack_range: float = 1.8
@export var move_speed: float = 2.0
@export var acceleration: float = 10.0
@export var turn_speed: float = 6.0

@export_group("Атака")
@export var attack_damage: int = 10
@export var attack_knockback: float = 5.0
## Скорость анимации удара: меньше — дольше замах, легче увернуться.
@export var attack_anim_speed: float = 0.75
@export var recover_time: float = 0.6

@export_group("Реакция на урон")
@export var light_stagger_time: float = 0.35
@export var heavy_stagger_time: float = 0.8
## Удар с таким отбросом и сильнее считается тяжёлым.
@export var heavy_knockback: float = 6.0
## Сколько секунд враг оглушён после контратаки героя.
@export var countered_time: float = 1.3
@export var respawn_time: float = 5.0

var state: State = State.IDLE

var _state_time: float = 0.0
var _stagger_time: float = 0.0
var _target: Node3D
var _spawn_transform: Transform3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model: CharacterModel = $Model
@onready var attack_area: Hitbox = $Model/AttackArea
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	_spawn_transform = global_transform
	attack_area.damage = attack_damage
	attack_area.knockback = attack_knockback
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	model.play(ANIM_IDLE, 0.0)
	_setup_counter_hint(2.9)


func _physics_process(delta: float) -> void:
	_state_time += delta
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player") as Node3D

	match state:
		State.IDLE:
			_update_idle(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.RECOVER:
			_update_recover(delta)
		State.STAGGER, State.COUNTERED:
			_update_stagger(delta)
		State.DEAD:
			_update_dead(delta)

	_update_counter_hint(_target)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


# --- Состояния ---------------------------------------------------------------


func _update_idle(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	model.play(ANIM_IDLE, 0.3)
	if _target_alive() and _to_target().length() <= aggro_range:
		_change_state(State.CHASE)


func _update_chase(delta: float) -> void:
	var to_target := _to_target()
	if not _target_alive() or to_target.length() > lose_range:
		_change_state(State.IDLE)
		return
	var dir := to_target.normalized()
	_face(dir, delta)
	if to_target.length() <= attack_range:
		_accelerate(Vector3.ZERO, delta)
		# Бьёт, только когда уже развернулся к герою.
		if _facing().dot(dir) > 0.8:
			_start_attack()
			return
	else:
		_accelerate((dir + _separation()).normalized() * move_speed, delta)
	_update_walk_animation()


func _start_attack() -> void:
	_change_state(State.ATTACK)
	model.play(ANIM_ATTACK, 0.15, attack_anim_speed, true)
	var windup := STRIKE_WINDOWS[0].x * model.get_animation_length(ANIM_ATTACK) / attack_anim_speed
	model.flash(WARNING_COLOR, windup, true)


func _update_attack(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	var progress := _attack_progress()
	# Во время замаха ещё доворачивается за героем, во время взмаха — уже нет.
	if progress < STRIKE_WINDOWS[0].x and _target:
		_face(_to_target().normalized(), delta)

	var striking := is_striking()
	if striking and not attack_area.active:
		model.clear_flash()
	attack_area.active = striking
	if progress >= 1.0:
		_change_state(State.RECOVER)


## Сейчас идёт взмах: в этот момент удары героя его не прерывают.
func is_striking() -> bool:
	if state != State.ATTACK:
		return false
	var progress := _attack_progress()
	for window: Vector2 in STRIKE_WINDOWS:
		if progress >= window.x and progress <= window.y:
			return true
	return false


func is_counterable() -> bool:
	if state != State.ATTACK:
		return false
	var progress := _attack_progress()
	return progress >= COUNTER_WINDOW.x and progress <= COUNTER_WINDOW.y


## Герой отвёл удар: атака прерывается, враг отшатывается и надолго открыт.
func receive_counter(from_position: Vector3) -> void:
	if state == State.DEAD:
		return
	var away := global_position - from_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -_facing()
	_change_state(State.COUNTERED)
	_stagger_time = countered_time
	_face_instant(-away)
	_set_horizontal_velocity(away * 2.5)
	model.flash(HIT_COLOR, 0.3)
	model.play(ANIM_HIT_HEAVY, 0.05, 1.0, true)


func _attack_progress() -> float:
	return _state_time * attack_anim_speed / model.get_animation_length(ANIM_ATTACK)


func _update_recover(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	model.play(ANIM_IDLE, 0.3)
	if _state_time >= recover_time:
		_change_state(State.CHASE)


func _update_stagger(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if _state_time >= _stagger_time:
		_change_state(State.CHASE)


func _update_dead(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if _state_time >= respawn_time:
		_respawn()


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	attack_area.active = false
	if new_state != State.ATTACK:
		model.clear_flash()


# --- Урон --------------------------------------------------------------------


func _on_hit_received(damage: int, source_position: Vector3, knockback: float) -> void:
	if state == State.DEAD:
		return
	var dealt := health.damage(damage)
	DamageNumber.spawn(
		get_parent(), global_position + Vector3.UP * 2.2, dealt, Color(1.0, 0.85, 0.3)
	)
	if health.is_dead():
		return
	# Во время взмаха лёгкие удары его не прерывают, а сильные — сбивают.
	if is_striking() and knockback < heavy_knockback:
		model.flash(HIT_COLOR, 0.15)
		return

	var heavy := knockback >= heavy_knockback
	# После контратаки лёгкие удары не сокращают его оглушение.
	if state == State.COUNTERED and not heavy:
		model.flash(HIT_COLOR, 0.15)
		return
	var away := global_position - source_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -_facing()
	_change_state(State.STAGGER)
	model.flash(HIT_COLOR, 0.15)
	_stagger_time = heavy_stagger_time if heavy else light_stagger_time
	_face_instant(-away)
	_set_horizontal_velocity(away * knockback * (1.0 if heavy else 0.5))
	model.play(ANIM_HIT_HEAVY if heavy else ANIM_HIT_LIGHT, 0.05, 1.0, true)


func _on_died() -> void:
	_change_state(State.DEAD)
	model.play(ANIM_DEATH, 0.1, 1.0, true)
	remove_from_group(&"enemies")
	collision_layer = 0
	hurtbox.set_deferred(&"monitorable", false)
	health_label.hide()


func _respawn() -> void:
	global_transform = _spawn_transform
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	health.reset()
	add_to_group(&"enemies")
	collision_layer = 1 << 2
	hurtbox.monitorable = true
	health_label.show()
	_change_state(State.IDLE)
	model.play(ANIM_IDLE, 0.0)


# --- Помощники ---------------------------------------------------------------


func _target_alive() -> bool:
	if _target == null:
		return false
	var player := _target as Player
	return player == null or player.state != Player.State.DEAD


func _to_target() -> Vector3:
	if _target == null:
		return Vector3.ZERO
	var v := _target.global_position - global_position
	v.y = 0.0
	return v


## Отталкивание от соседей, чтобы одержимые обходили друг друга, а не слипались.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Node3D
		if other == null or other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.01 and distance < SEPARATION_RADIUS:
			push += away.normalized() * (1.0 - distance / SEPARATION_RADIUS)
	return push


func _update_walk_animation() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.1:
		model.play(ANIM_IDLE, 0.3)
		return
	model.play(ANIM_WALK, 0.25)
	model.set_playback_speed(clampf(speed / WALK_ANIM_SPEED, 0.5, 2.2))


func _accelerate(target: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	_set_horizontal_velocity(horizontal.move_toward(target, acceleration * delta))


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _facing() -> Vector3:
	var z := model.global_basis.z
	return Vector3(z.x, 0.0, z.z).normalized()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(dir.x, dir.z)
	model.global_rotation.y = lerp_angle(
		model.global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta)
	)


func _face_instant(dir: Vector3) -> void:
	if dir.length() >= 0.01:
		model.global_rotation.y = atan2(dir.x, dir.z)
