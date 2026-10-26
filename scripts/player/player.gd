class_name Player
extends CharacterBody3D
## Серёга: шаг/бег/спринт, кувырок, удары оружием (лёгкая серия и заряжаемый сильный удар),
## блок, бросок пороховой бомбы и подбор оружия. Удары и блок берутся из WeaponData.
## Получает урон: блок спереди гасит удар, кувырок даёт неуязвимость.
##
## Управление (клавиатура / геймпад Xbox): WASD / левый стик — движение
## (слабый наклон стика — шаг), Shift / B (удерживать) — спринт, Пробел / A — кувырок,
## ЛКМ / X — удар (удерживать — заряженный сильный), RT — сильный удар сразу,
## ПКМ / LT, LB (удерживать) — блок, Q / RB — бомба, E / Y — подобрать оружие.
## С мышью удары и броски летят в курсор, с геймпадом — по правому стику
## (или по направлению движения) с мягким автонаведением на ближайшего врага.

signal weapon_changed(weapon: WeaponData)

enum State { NORMAL, ATTACK, CHARGE, BLOCK, ROLL, THROW, HIT, DEAD }

const ANIM_IDLE: StringName = &"Idle"
const ANIM_WALK: StringName = &"Walk"
const ANIM_JOG: StringName = &"Jog_Fwd"
const ANIM_SPRINT: StringName = &"Sprint"
const ANIM_ROLL: StringName = &"Roll"
const ANIM_THROW: StringName = &"OverhandThrow"
const ANIM_HIT: StringName = &"Hit_Chest"
const ANIM_DEATH: StringName = &"Death01"

# Скорость тела внутри анимаций, м/с (измерено по root motion из UAL1_Standard_RM).
# Делим на неё реальную скорость, чтобы ноги не скользили по земле.
const WALK_ANIM_SPEED: float = 0.97
const JOG_ANIM_SPEED: float = 5.36
const SPRINT_ANIM_SPEED: float = 8.25
const ROLL_ANIM_SPEED: float = 5.75
## Доля анимации кувырка, пока тело катится; дальше герой встаёт на месте.
const ROLL_MOVE_END: float = 0.6
## Неуязвимость во время кувырка (доли анимации, от и до).
const ROLL_IFRAMES := Vector2(0.05, 0.45)
## С этой доли кувырка можно прервать вставание движением или ударом.
const ROLL_CANCEL: float = 0.75

## Наклон стика меньше этого — шаг, больше — бег.
const STICK_WALK_THRESHOLD: float = 0.55
## Сколько секунд после боя герой держит боевую стойку вместо обычной.
const COMBAT_IDLE_TIME: float = 4.0

## Кнопку удара держат дольше этого — начинается заряд сильного удара.
const CHARGE_THRESHOLD: float = 0.25
## За сколько секунд удар заряжается полностью.
const FULL_CHARGE_TIME: float = 1.0
## Полный заряд добавляет к урону и отбросу эту долю.
const CHARGE_BONUS: float = 0.5
const CHARGE_COLOR := Color(1.0, 0.75, 0.3, 0.5)

const THROW_SPEED: float = 1.2
## Момент выпуска бомбы, в секундах анимации броска.
const THROW_RELEASE_TIME: float = 0.55

## Сколько секунд герой оглушён после пропущенного удара.
const HIT_STUN_TIME: float = 0.4
## Через сколько секунд после смерти герой возрождается.
const RESPAWN_TIME: float = 3.0
## Длительность «заморозки» мира при попадании — для веса удара (сильный — дольше).
const HITSTOP_TIME: float = 0.05
const HEAVY_HITSTOP_TIME: float = 0.1

## Автонаведение для геймпада: дальность и ширина конуса (косинус угла ≈ 40°).
const AUTO_AIM_RANGE: float = 6.0
const AUTO_AIM_MIN_DOT: float = 0.77
## Куда летит бомба с геймпада, если врага рядом нет.
const GAMEPAD_THROW_DISTANCE: float = 7.0

@export_group("Движение")
@export var walk_speed: float = 1.6
@export var run_speed: float = 5.0
@export var sprint_speed: float = 7.5
## Разгон и торможение, м/с².
@export var acceleration: float = 30.0
@export var deceleration: float = 40.0
@export var turn_speed: float = 14.0
## На спринте герой поворачивает тяжелее.
@export var sprint_turn_speed: float = 7.0

@export_group("Кувырок")
## Множитель скорости анимации кувырка (1.0 — как в анимации, 5 м за 0.87 с).
@export var roll_anim_speed: float = 1.25
@export var roll_cooldown: float = 0.25

@export_group("Бой")
@export var starting_weapon: WeaponData
@export var throw_range: float = 12.0

@export_group("Ссылки")
@export var camera: TopDownCamera
@export var bomb_scene: PackedScene

var state: State = State.NORMAL
var weapon: WeaponData
## Для автотестов и катсцен: если задано, герой целится сюда, а не в курсор.
var aim_point_override: Vector3 = Vector3.INF
## Оружие на земле, которое сейчас можно подобрать (его выставляет WeaponPickup).
var pickup_candidate: WeaponPickup

var _state_time: float = 0.0
var _attack: AttackData
## Номер удара в лёгкой серии; -1 — сильный удар.
var _combo_index: int = -1
var _combo_queued: bool = false
var _attack_multiplier: float = 1.0
## Кнопку удара нажали в обычном состоянии: ждём — отпустят (лёгкий) или задержат (заряд).
var _attack_pending: bool = false
var _attack_hold_time: float = 0.0
var _charge: float = 0.0
var _block_reaction_left: float = 0.0
var _roll_dir: Vector3 = Vector3.ZERO
var _roll_cooldown_left: float = 0.0
var _combat_time_left: float = 0.0
var _bomb_thrown: bool = false
var _throw_target: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_transform: Transform3D
var _weapon_nodes: Array[Node] = []
var _attack_box: BoxShape3D

@onready var model: CharacterModel = $Model
@onready var attack_area: Hitbox = $Model/AttackArea
@onready var attack_shape: CollisionShape3D = $Model/AttackArea/CollisionShape3D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health


func _ready() -> void:
	_spawn_transform = global_transform
	# Своя копия формы: размер зоны удара меняется под каждый удар.
	_attack_box = (attack_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	attack_shape.shape = _attack_box
	if starting_weapon:
		equip(starting_weapon)
	model.play(ANIM_IDLE, 0.0)
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	attack_area.hit_landed.connect(_on_attack_landed)


## Берёт оружие в руки: вешает модели на кости и подставляет удары и блок.
func equip(new_weapon: WeaponData) -> void:
	for node: Node in _weapon_nodes:
		node.queue_free()
	_weapon_nodes.clear()
	weapon = new_weapon
	if weapon.main_hand:
		_weapon_nodes.append(
			model.attach_to_bone(weapon.main_hand.instantiate() as Node3D, &"hand_r")
		)
	if weapon.off_hand:
		_weapon_nodes.append(
			model.attach_to_bone(weapon.off_hand.instantiate() as Node3D, &"hand_l")
		)
	weapon_changed.emit(weapon)


func is_blocking() -> bool:
	return state == State.BLOCK


## Во время кувырка герой ненадолго неуязвим.
func is_invulnerable() -> bool:
	if state != State.ROLL:
		return false
	var progress := _roll_progress()
	return progress >= ROLL_IFRAMES.x and progress <= ROLL_IFRAMES.y


func _physics_process(delta: float) -> void:
	_state_time += delta
	_roll_cooldown_left = maxf(_roll_cooldown_left - delta, 0.0)
	_combat_time_left = maxf(_combat_time_left - delta, 0.0)

	match state:
		State.NORMAL:
			_update_normal(delta)
		State.ATTACK:
			_update_attack(delta)
		State.CHARGE:
			_update_charge(delta)
		State.BLOCK:
			_update_block(delta)
		State.ROLL:
			_update_roll(delta)
		State.THROW:
			_update_throw(delta)
		State.HIT:
			_update_hit(delta)
		State.DEAD:
			_update_dead(delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


# --- Движение ----------------------------------------------------------------


func _update_normal(delta: float) -> void:
	var dir := _input_direction()
	var strength := dir.length()
	var target_speed := 0.0
	if strength > 0.0:
		if Input.is_action_pressed(&"sprint"):
			target_speed = sprint_speed
		elif strength < STICK_WALK_THRESHOLD:
			target_speed = walk_speed
		else:
			target_speed = run_speed
		var turn := sprint_turn_speed if target_speed >= sprint_speed else turn_speed
		_face(dir, delta, turn)
	_accelerate(dir.normalized() * target_speed, delta)
	_update_locomotion_animation()

	if _update_attack_button(delta):
		return
	if Input.is_action_just_pressed(&"heavy_attack"):
		_start_heavy(false)
	elif Input.is_action_pressed(&"block"):
		_start_block()
	elif _try_roll():
		pass
	elif Input.is_action_just_pressed(&"throw") and bomb_scene:
		_start_throw()
	elif Input.is_action_just_pressed(&"interact") and pickup_candidate:
		pickup_candidate.take(self)


## Анимация ходьбы по реальной скорости: стойка → шаг → бег → спринт,
## и скорость анимации подгоняется так, чтобы шаги совпадали с перемещением.
func _update_locomotion_animation() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.15:
		var combat_idle := weapon.combat_idle if weapon else ANIM_IDLE
		model.play(combat_idle if _combat_time_left > 0.0 else ANIM_IDLE, 0.25)
		return
	var anim := ANIM_WALK
	var anim_speed := WALK_ANIM_SPEED
	if speed > (run_speed + sprint_speed) * 0.5:
		anim = ANIM_SPRINT
		anim_speed = SPRINT_ANIM_SPEED
	elif speed > (walk_speed + run_speed) * 0.5:
		anim = ANIM_JOG
		anim_speed = JOG_ANIM_SPEED
	model.play(anim, 0.2)
	model.set_playback_speed(clampf(speed / anim_speed, 0.5, 1.8))


# --- Удары -------------------------------------------------------------------


## Короткое нажатие — лёгкий удар, удержание — заряд сильного. Возвращает true,
## если начался удар или заряд.
func _update_attack_button(delta: float) -> bool:
	if weapon == null:
		return false
	if Input.is_action_just_pressed(&"attack"):
		_attack_pending = true
		_attack_hold_time = 0.0
	if not _attack_pending:
		return false
	if Input.is_action_pressed(&"attack"):
		_attack_hold_time += delta
		if _attack_hold_time >= CHARGE_THRESHOLD and weapon.heavy_attack:
			_attack_pending = false
			_start_charge()
			return true
		return false
	_attack_pending = false
	_start_light(0)
	return true


func _start_light(index: int) -> void:
	if weapon.light_combo.is_empty():
		return
	_combo_index = index
	_begin_attack(weapon.light_combo[index], 1.0)
	_face_instant(_aim_direction())
	model.play(_attack.animation, 0.08, _attack.anim_speed, true)


## Сильный удар. charged = true — после заряда (анимация продолжается с позы замаха).
func _start_heavy(charged: bool) -> void:
	if weapon == null or weapon.heavy_attack == null:
		return
	_combo_index = -1
	_begin_attack(weapon.heavy_attack, 1.0 + CHARGE_BONUS * _charge if charged else 1.0)
	model.clear_flash()
	if charged:
		# Продолжаем с позы замаха, на которой анимация замерла.
		_state_time = _attack.charge_pose * _attack.duration(model)
		model.play(_attack.animation)
		model.flash(Color(1.0, 0.95, 0.8, 0.6), 0.15)
	else:
		_face_instant(_aim_direction())
		model.play(_attack.animation, 0.08, _attack.anim_speed, true)


func _begin_attack(attack: AttackData, multiplier: float) -> void:
	_change_state(State.ATTACK)
	_attack = attack
	_attack_multiplier = multiplier
	_combo_queued = false
	_combat_time_left = COMBAT_IDLE_TIME
	attack_area.damage = roundi(attack.damage * multiplier)
	attack_area.knockback = attack.knockback * multiplier
	_attack_box.size = attack.hitbox_size
	attack_shape.position = attack.hitbox_offset


func _update_attack(delta: float) -> void:
	var length := _attack.duration(model)
	var progress := _state_time / length
	attack_area.active = _attack.is_in_hit_window(progress)

	var lunge := _attack.lunge_window
	if _attack.lunge_distance > 0.0 and progress >= lunge.x and progress <= lunge.y:
		var lunge_speed := _attack.lunge_distance / maxf((lunge.y - lunge.x) * length, 0.01)
		_set_horizontal_velocity(_facing() * lunge_speed)
	else:
		_accelerate(Vector3.ZERO, delta)

	if progress >= _attack.cancel_from and _try_roll():
		return
	if Input.is_action_just_pressed(&"attack"):
		_combo_queued = true
	var in_combo := _combo_index >= 0
	var has_next := in_combo and _combo_index < weapon.light_combo.size() - 1
	if _combo_queued and has_next and progress >= _attack.combo_from:
		_start_light(_combo_index + 1)
	elif progress >= _attack.end_at:
		_change_state(State.NORMAL)
		# Нажали во время последнего удара — серия начинается заново.
		if _combo_queued:
			_start_light(0)


func _start_charge() -> void:
	_change_state(State.CHARGE)
	_charge = 0.0
	_combat_time_left = COMBAT_IDLE_TIME
	var heavy := weapon.heavy_attack
	_face_instant(_aim_direction())
	model.play(heavy.animation, 0.1, heavy.anim_speed, true)
	model.flash(CHARGE_COLOR, FULL_CHARGE_TIME, true)


func _update_charge(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	_face(_aim_direction(), delta, turn_speed * 0.5)
	var heavy := weapon.heavy_attack
	# Замах доходит до позы и замирает, пока держат кнопку.
	if _state_time >= heavy.charge_pose * heavy.duration(model) and model.is_playing():
		model.pause()
	_charge = clampf(_state_time / FULL_CHARGE_TIME, 0.0, 1.0)
	if _try_roll():
		model.clear_flash()
		return
	if not Input.is_action_pressed(&"attack"):
		_start_heavy(true)


# --- Блок --------------------------------------------------------------------


func _start_block() -> void:
	_combat_time_left = COMBAT_IDLE_TIME
	_block_reaction_left = 0.0
	_change_state(State.BLOCK)
	model.play(weapon.block_animation if weapon else &"Sword_Block", 0.1, 1.0, true)


func _update_block(delta: float) -> void:
	_combat_time_left = COMBAT_IDLE_TIME
	var move_speed := weapon.block_move_speed if weapon else 0.0
	_accelerate(_input_direction() * move_speed, delta)
	_face(_aim_direction(), delta, turn_speed)
	if _try_roll():
		return
	if _block_reaction_left > 0.0:
		_block_reaction_left -= delta
		if _block_reaction_left <= 0.0:
			model.play(weapon.block_animation, 0.15)
	elif weapon and weapon.block_hold_time > 0.0:
		if _state_time >= weapon.block_hold_time and model.is_playing():
			model.pause()
	if not Input.is_action_pressed(&"block"):
		_change_state(State.NORMAL)


## Удар пришёлся в блок: урон по доле оружия, отдача, вспышка.
func _on_blocked(damage: int, away: Vector3, knockback: float) -> void:
	var passed := ceili(damage * weapon.block_damage_factor)
	if passed > 0:
		health.damage(passed)
	_set_horizontal_velocity(away * knockback * weapon.block_pushback)
	model.flash(Color(0.6, 0.8, 1.0, 0.5), 0.2)
	_shake_camera(0.25)
	_vibrate(0.3, 0.0, 0.12)
	if weapon.block_hit_animation != &"":
		model.play(weapon.block_hit_animation, 0.05, 1.0, true)
		_block_reaction_left = model.get_animation_length(weapon.block_hit_animation)


# --- Кувырок и бомба ---------------------------------------------------------


## Начинает кувырок, если нажата кнопка и он не на перезарядке.
func _try_roll() -> bool:
	if not Input.is_action_just_pressed(&"roll") or _roll_cooldown_left > 0.0:
		return false
	var dir := _input_direction()
	_roll_dir = dir.normalized() if dir != Vector3.ZERO else _facing()
	_face_instant(_roll_dir)
	_attack_pending = false
	_change_state(State.ROLL)
	model.play(ANIM_ROLL, 0.05, roll_anim_speed, true)
	return true


func _update_roll(delta: float) -> void:
	var progress := _roll_progress()
	if progress < ROLL_MOVE_END:
		_set_horizontal_velocity(_roll_dir * ROLL_ANIM_SPEED * roll_anim_speed)
	else:
		_accelerate(Vector3.ZERO, delta)

	var wants_to_act := (
		_input_direction() != Vector3.ZERO
		or Input.is_action_just_pressed(&"attack")
		or Input.is_action_just_pressed(&"roll")
	)
	if progress >= 1.0 or (progress >= ROLL_CANCEL and wants_to_act):
		_roll_cooldown_left = roll_cooldown
		_change_state(State.NORMAL)
		_update_normal(delta)


func _roll_progress() -> float:
	return _state_time * roll_anim_speed / model.get_animation_length(ANIM_ROLL)


func _start_throw() -> void:
	var offset := _aim_point() - global_position
	offset.y = 0.0
	offset = offset.limit_length(throw_range)
	_throw_target = global_position + offset
	_bomb_thrown = false
	_combat_time_left = COMBAT_IDLE_TIME
	_face_instant(offset)
	_change_state(State.THROW)
	model.play(ANIM_THROW, 0.1, THROW_SPEED, true)


func _update_throw(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if not _bomb_thrown and _state_time >= THROW_RELEASE_TIME / THROW_SPEED:
		_bomb_thrown = true
		var bomb := bomb_scene.instantiate() as Bomb
		get_parent().add_child(bomb)
		bomb.launch(model.get_bone_global_position(&"hand_r"), _throw_target, 0.7)
	if _bomb_thrown and _try_roll():
		return
	if _state_time >= 0.85 * model.get_animation_length(ANIM_THROW) / THROW_SPEED:
		_change_state(State.NORMAL)


# --- Урон по герою -----------------------------------------------------------


func _on_hit_received(damage: int, source_position: Vector3, knockback: float) -> void:
	if state == State.DEAD or is_invulnerable():
		return
	var from_attacker := source_position - global_position
	from_attacker.y = 0.0
	var away := -from_attacker.normalized() if from_attacker.length() > 0.01 else -_facing()
	var min_dot := weapon.block_min_dot if weapon else 0.34
	if state == State.BLOCK and _facing().dot(-away) >= min_dot:
		_on_blocked(damage, away, knockback)
		return

	health.damage(damage)
	model.flash(Color(1.0, 0.15, 0.1, 0.6), 0.3)
	_shake_camera(0.6)
	_vibrate(0.5, 0.8, 0.25)
	if health.is_dead():
		return
	_change_state(State.HIT)
	_face_instant(-away)
	_set_horizontal_velocity(away * knockback)
	model.play(ANIM_HIT, 0.05, 1.0, true)


func _update_hit(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if _state_time >= HIT_STUN_TIME:
		_change_state(State.NORMAL)


func _on_died() -> void:
	_change_state(State.DEAD)
	model.play(ANIM_DEATH, 0.1, 1.0, true)


func _update_dead(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if _state_time >= RESPAWN_TIME:
		global_transform = _spawn_transform
		reset_physics_interpolation()
		velocity = Vector3.ZERO
		health.reset()
		_change_state(State.NORMAL)
		model.play(ANIM_IDLE, 0.0)


## Короткая заморозка мира при попадании — удар ощущается весомее.
func _on_attack_landed(_target: Hurtbox) -> void:
	var heavy := _combo_index < 0
	_vibrate(0.4, 0.5 if heavy else 0.2, 0.12 if heavy else 0.08)
	if heavy:
		_shake_camera(0.35)
	Engine.time_scale = 0.05
	var pause := HEAVY_HITSTOP_TIME if heavy else HITSTOP_TIME
	await get_tree().create_timer(pause, true, false, true).timeout
	Engine.time_scale = 1.0


func _shake_camera(strength: float) -> void:
	if camera:
		camera.shake(strength)


func _vibrate(weak: float, strong: float, duration: float) -> void:
	if InputDevice.is_gamepad():
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, weak, strong, duration)


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


## Плавно меняет горизонтальную скорость к target: разгон и торможение с разной силой.
func _accelerate(target: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if target.length() > horizontal.length() else deceleration
	_set_horizontal_velocity(horizontal.move_toward(target, rate * delta))


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


## Куда смотрит модель (по горизонтали).
func _facing() -> Vector3:
	var z := model.global_basis.z
	return Vector3(z.x, 0.0, z.z).normalized()


func _face(dir: Vector3, delta: float, speed: float) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(dir.x, dir.z)
	model.global_rotation.y = lerp_angle(
		model.global_rotation.y, target_yaw, 1.0 - exp(-speed * delta)
	)


func _face_instant(dir: Vector3) -> void:
	if dir.length() >= 0.01:
		model.global_rotation.y = atan2(dir.x, dir.z)


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
