class_name Player
extends CharacterBody3D
## Серёга: шаг/бег/спринт, кувырок, удары оружием (лёгкая серия и заряжаемый сильный удар),
## блок, бросок пороховой бомбы, подбор оружия и щита. Удары и блок — из WeaponData,
## со щитом блок и сильный удар — из ShieldData; щит изнашивается и ломается.
## Получает урон: блок спереди гасит удар, кувырок даёт неуязвимость.
## Выносливость (Stamina) тратится на удары, кувырок, спринт, контратаку, бросок
## и удары в блок; если в блоке она кончилась — блок пробит.
##
## Управление (клавиатура / геймпад Xbox): WASD / левый стик — движение
## (слабый наклон стика — шаг), Shift / B (удерживать) — спринт, Пробел / A — кувырок,
## ЛКМ / X — удар (удерживать — заряженный сильный), RT — сильный удар сразу,
## ПКМ / LT (удерживать) — блок, F / колесо / LB — контратака (когда над врагом «!»),
## Q / RB — бомба, R / R3 — выстрел из пищали (пустая — перезарядка), E / Y — подобрать,
## колесо мыши (нажатие) / T / R3 — захват цели (смена цели — колёсико / рывок правого стика),
## Tab / крестовина вверх — сменить оружие в руках (1 — меч, 2 — пищаль): с пищалью в руках
## удар = выстрел, блок — только щитом, сильного удара и контратаки нет,
## удерживать E / Y — выбросить щит.
## С мышью удары и броски летят в курсор, с геймпадом — по правому стику
## (или по направлению движения) с мягким автонаведением на ближайшего врага.

signal weapon_changed(weapon: WeaponData)
signal shield_changed(shield: ShieldData, durability: int)
signal firearm_changed(firearm: FirearmData, loaded: bool, powder: int)
## В руках сменилось оружие: true — пищаль, false — меч.
signal ranged_mode_changed(ranged: bool)

enum State { NORMAL, ATTACK, CHARGE, BLOCK, COUNTER, ROLL, THROW, SHOOT, RELOAD, HIT, DEAD }

const ANIM_IDLE: StringName = &"Idle"
const ANIM_WALK: StringName = &"Walk"
const ANIM_JOG: StringName = &"Jog_Fwd"
const ANIM_SPRINT: StringName = &"Sprint"
const ANIM_ROLL: StringName = &"Roll"
const ANIM_THROW: StringName = &"OverhandThrow"
const ANIM_HIT: StringName = &"Hit_Chest"
const ANIM_DEATH: StringName = &"Death01"
const ANIM_SHIELD_BREAK: StringName = &"Idle_Shield_Break"
const ANIM_DEFLECT: StringName = &"Sword_Block"

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

## Контратака: дальность поиска врага, длительность отведения удара перед ответом,
## длительность и перезарядка промаха, замедление времени при успехе.
const COUNTER_RANGE: float = 2.5
const COUNTER_DEFLECT_TIME: float = 0.2
const COUNTER_WHIFF_TIME: float = 0.4
const COUNTER_COOLDOWN: float = 0.6
const COUNTER_SLOWMO_SCALE: float = 0.3
const COUNTER_SLOWMO_TIME: float = 0.3
## Номер «удара серии» для ответного удара контратаки (у сильного удара -1).
const RIPOSTE_INDEX: int = -2

const THROW_SPEED: float = 1.2
## Момент выпуска бомбы, в секундах анимации броска.
const THROW_RELEASE_TIME: float = 0.55

## Сколько секунд герой оглушён после пропущенного удара и после поломки щита.
const HIT_STUN_TIME: float = 0.4
const SHIELD_BREAK_STUN_TIME: float = 0.6
## Оглушение, когда в блоке кончилась выносливость (блок пробит).
const GUARD_BREAK_STUN_TIME: float = 0.8
## Сколько держать «подобрать», чтобы выбросить щит.
const DROP_HOLD_TIME: float = 0.5
const SHIELD_DEBRIS_COLOR := Color(0.45, 0.28, 0.14)
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

@export_group("Выносливость")
@export var roll_stamina_cost: float = 22.0
## Расход на спринте, в секунду.
@export var sprint_stamina_per_second: float = 18.0
@export var counter_stamina_cost: float = 12.0
@export var throw_stamina_cost: float = 10.0

@export_group("Бой")
@export var starting_weapon: WeaponData
@export var starting_firearm: FirearmData
## Сколько зарядов пороха у героя в начале.
@export var starting_powder: int = 5
@export var throw_range: float = 12.0

@export_group("Ссылки")
@export var camera: TopDownCamera
@export var bomb_scene: PackedScene

var state: State = State.NORMAL
var weapon: WeaponData
var shield: ShieldData
var shield_durability: int = 0
var firearm: FirearmData
var firearm_loaded: bool = false
var powder: int = 0
## Пищаль в руках (вместо меча).
var ranged_mode: bool = false
## Для автотестов и катсцен: если задано, герой целится сюда, а не в курсор.
var aim_point_override: Vector3 = Vector3.INF
## Предмет на земле, который сейчас можно подобрать (его выставляет ItemPickup).
var pickup_candidate: ItemPickup

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
var _stun_time: float = HIT_STUN_TIME
var _interact_pending: bool = false
var _interact_hold_time: float = 0.0
var _shield_node: Node3D
var _counter_success: bool = false
var _counter_cooldown_left: float = 0.0
var _roll_dir: Vector3 = Vector3.ZERO
var _roll_cooldown_left: float = 0.0
var _combat_time_left: float = 0.0
var _bomb_thrown: bool = false
var _throw_target: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_transform: Transform3D
var _weapon_nodes: Array[Node] = []
var _attack_box: BoxShape3D
var _gun_node: Node3D
var _shot_fired: bool = false
var _target_lock: TargetLock
var _aim_guide: AimGuide

@onready var model: CharacterModel = $Model
@onready var attack_area: Hitbox = $Model/AttackArea
@onready var attack_shape: CollisionShape3D = $Model/AttackArea/CollisionShape3D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var stamina: Stamina = $Stamina


func _ready() -> void:
	_spawn_transform = global_transform
	# Своя копия формы: размер зоны удара меняется под каждый удар.
	_attack_box = (attack_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	attack_shape.shape = _attack_box
	if starting_weapon:
		equip(starting_weapon)
	if starting_firearm:
		powder = starting_powder
		equip_firearm(starting_firearm, true)
	model.play(ANIM_IDLE, 0.0)
	_target_lock = TargetLock.new()
	add_child(_target_lock)
	_target_lock.setup(self)
	_target_lock.target_changed.connect(_on_target_changed)
	_aim_guide = AimGuide.new()
	add_child(_aim_guide)
	_aim_guide.setup(self)
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	attack_area.hit_landed.connect(_on_attack_landed)


## Берёт оружие в правую руку: вешает модель на кость и подставляет удары и блок.
func equip(new_weapon: WeaponData) -> void:
	for node: Node in _weapon_nodes:
		node.queue_free()
	_weapon_nodes.clear()
	weapon = new_weapon
	if weapon.main_hand:
		_weapon_nodes.append(
			model.attach_to_bone(weapon.main_hand.instantiate() as Node3D, &"RightHand")
		)
	# Двуручное оружие со щитом не носят — щит падает на землю.
	if shield and not weapon.one_handed:
		drop_shield()
	_show_gun(ranged_mode)
	weapon_changed.emit(weapon)


## Вешает пищаль на пояс (модель в руке появляется только при стрельбе и перезарядке).
func equip_firearm(data: FirearmData, loaded: bool) -> void:
	if _gun_node:
		_gun_node.queue_free()
	firearm = data
	firearm_loaded = loaded
	_gun_node = model.attach_to_bone(data.model.instantiate() as Node3D, &"RightHand")
	_show_gun(ranged_mode)
	firearm_changed.emit(firearm, firearm_loaded, powder)


## Берёт в руки пищаль (true) или меч (false). Пищаль остаётся в руках, пока не сменишь.
func set_ranged_mode(on: bool) -> void:
	if on and firearm == null:
		return
	if on == ranged_mode:
		return
	ranged_mode = on
	_attack_pending = false
	_combat_time_left = COMBAT_IDLE_TIME
	_show_gun(on)
	ranged_mode_changed.emit(on)


## Берёт щит в левую руку. durability < 0 — новый щит с полной прочностью.
func equip_shield(data: ShieldData, durability: int = -1) -> void:
	_remove_shield_model()
	shield = data
	shield_durability = durability if durability >= 0 else data.max_durability
	var shield_model := data.model.instantiate() as Node3D
	_shield_node = model.attach_to_bone(shield_model, &"LeftHand")
	ShieldWear.apply(_shield_node, shield_durability, shield.max_durability)
	shield_changed.emit(shield, shield_durability)


## Кладёт щит на землю перед собой — с той прочностью, что у него осталась.
func drop_shield() -> void:
	if shield == null:
		return
	var at := global_position + _facing() * 0.9
	ItemPickup.drop_shield(get_parent(), at, shield, shield_durability)
	_remove_shield_model()
	shield = null
	shield_durability = 0
	shield_changed.emit(null, 0)


func _remove_shield_model() -> void:
	if _shield_node:
		_shield_node.queue_free()
		_shield_node = null


func is_blocking() -> bool:
	return state == State.BLOCK


## Неуязвим: в начале кувырка и во время удачной контратаки (до конца ответного удара).
func is_invulnerable() -> bool:
	match state:
		State.ROLL:
			var progress := _roll_progress()
			return progress >= ROLL_IFRAMES.x and progress <= ROLL_IFRAMES.y
		State.COUNTER:
			return _counter_success
		State.ATTACK:
			return _combo_index == RIPOSTE_INDEX
	return false


func _physics_process(delta: float) -> void:
	_state_time += delta
	_roll_cooldown_left = maxf(_roll_cooldown_left - delta, 0.0)
	_combat_time_left = maxf(_combat_time_left - delta, 0.0)
	_counter_cooldown_left = maxf(_counter_cooldown_left - delta, 0.0)
	var block := _block_data()
	var blocking := state == State.BLOCK and block != null
	stamina.regen_multiplier = block.stamina_regen_multiplier if blocking else 1.0

	match state:
		State.NORMAL:
			_update_normal(delta)
		State.ATTACK:
			_update_attack(delta)
		State.CHARGE:
			_update_charge(delta)
		State.BLOCK:
			_update_block(delta)
		State.COUNTER:
			_update_counter(delta)
		State.ROLL:
			_update_roll(delta)
		State.THROW:
			_update_throw(delta)
		State.SHOOT:
			_update_shoot(delta)
		State.RELOAD:
			_update_reload(delta)
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
		# Выдохся — спринта нет, пока выносливость не наберётся.
		if Input.is_action_pressed(&"sprint") and not stamina.is_exhausted:
			target_speed = sprint_speed
		elif strength < STICK_WALK_THRESHOLD:
			target_speed = walk_speed
		else:
			target_speed = run_speed
		var turn := sprint_turn_speed if target_speed >= sprint_speed else turn_speed
		_face(dir, delta, turn)
	_accelerate(dir.normalized() * target_speed, delta)
	# Спринт тратит выносливость, только пока герой действительно бежит (а не упёрся в стену).
	var real := get_real_velocity()
	var moving_fast := Vector2(real.x, real.z).length() > run_speed
	if target_speed >= sprint_speed and moving_fast:
		stamina.spend(sprint_stamina_per_second * delta)
	_update_locomotion_animation()

	if _update_weapon_switch():
		return
	if ranged_mode:
		if Input.is_action_just_pressed(&"attack"):
			_start_shoot_or_reload()
			return
	else:
		if _update_attack_button(delta):
			return
		if _try_counter():
			return
	if Input.is_action_just_pressed(&"heavy_attack") and not ranged_mode:
		_start_heavy(false)
	elif Input.is_action_pressed(&"block") and _can_block():
		_start_block()
	elif _try_roll():
		pass
	elif Input.is_action_just_pressed(&"shoot") and firearm:
		_start_shoot_or_reload()
	elif Input.is_action_just_pressed(&"throw") and bomb_scene:
		if stamina.try_spend(throw_stamina_cost):
			_start_throw()
	else:
		_update_interact_button(delta)


## Смена оружия в руках. Возвращает true, если оружие сменили.
func _update_weapon_switch() -> bool:
	var want := ranged_mode
	if Input.is_action_just_pressed(&"switch_weapon"):
		want = not ranged_mode
	elif Input.is_action_just_pressed(&"select_melee"):
		want = false
	elif Input.is_action_just_pressed(&"select_firearm"):
		want = true
	if want == ranged_mode:
		return false
	set_ranged_mode(want)
	return want == ranged_mode


## С пищалью в руках блок возможен только щитом.
func _can_block() -> bool:
	return not ranged_mode or shield != null


## Короткое нажатие «подобрать» — взять предмет рядом, удержание — выбросить щит.
func _update_interact_button(delta: float) -> void:
	if Input.is_action_just_pressed(&"interact"):
		_interact_pending = true
		_interact_hold_time = 0.0
	if not _interact_pending:
		return
	if Input.is_action_pressed(&"interact"):
		_interact_hold_time += delta
		if _interact_hold_time >= DROP_HOLD_TIME:
			_interact_pending = false
			drop_shield()
		return
	_interact_pending = false
	if pickup_candidate and pickup_candidate.can_take(self):
		pickup_candidate.take(self)


## Блок со щитом — от щита, без него — от оружия.
func _block_data() -> BlockData:
	if shield and shield.block:
		return shield.block
	return weapon.block if weapon else null


## Сильный удар: со щитом — удар щитом, без него — сильный удар оружия.
func _heavy_attack() -> AttackData:
	if shield and shield.bash_attack:
		return shield.bash_attack
	return weapon.heavy_attack if weapon else null


## Анимация ходьбы по реальной скорости: стойка → шаг → бег → спринт,
## и скорость анимации подгоняется так, чтобы шаги совпадали с перемещением.
func _update_locomotion_animation() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.15:
		if ranged_mode:
			model.play(firearm.idle_animation, 0.25)
			return
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
		if _attack_hold_time >= CHARGE_THRESHOLD and _heavy_attack():
			_attack_pending = false
			# Заряд начинается, если есть хоть сколько-то выносливости; тратится она при ударе.
			if not stamina.has_any():
				stamina.denied.emit()
				return false
			_start_charge()
			return true
		return false
	_attack_pending = false
	return _start_light(0)


## Лёгкий удар серии. Возвращает false, если не хватило выносливости.
func _start_light(index: int) -> bool:
	if weapon.light_combo.is_empty():
		return false
	if not stamina.try_spend(weapon.light_combo[index].stamina_cost):
		return false
	_combo_index = index
	_begin_attack(weapon.light_combo[index], 1.0)
	_face_instant(_aim_direction())
	model.play(_attack.animation, 0.08, _attack.anim_speed, true)
	return true


## Сильный удар. charged = true — после заряда (анимация продолжается с позы замаха).
func _start_heavy(charged: bool) -> void:
	var heavy := _heavy_attack()
	if heavy == null:
		return
	# После заряда выносливость проверена в его начале — тратим без отказа.
	if charged:
		stamina.spend(heavy.stamina_cost)
	elif not stamina.try_spend(heavy.stamina_cost):
		return
	_combo_index = -1
	_begin_attack(heavy, 1.0 + CHARGE_BONUS * _charge if charged else 1.0)
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
		_combo_queued = false
		_start_light(_combo_index + 1)
	elif progress >= _attack.end_at:
		_change_state(State.NORMAL)
		# Нажали во время последнего удара — серия начинается заново.
		if _combo_queued:
			_start_light(0)


func _start_charge() -> void:
	_change_state(State.CHARGE)
	_attack = _heavy_attack()
	_charge = 0.0
	_combat_time_left = COMBAT_IDLE_TIME
	var heavy := _heavy_attack()
	_face_instant(_aim_direction())
	model.play(heavy.animation, 0.1, heavy.anim_speed, true)
	model.flash(CHARGE_COLOR, FULL_CHARGE_TIME, true)


func _update_charge(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	_face(_aim_direction(), delta, turn_speed * 0.5)
	var heavy := _attack
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
	# Корпус и руки держат блок в верхнем слое, ногами управляет _update_upper_body_legs.
	model.play_upper(_block_data().animation, 0.1, 1.0, true)


func _update_block(delta: float) -> void:
	_combat_time_left = COMBAT_IDLE_TIME
	var block := _block_data()
	_accelerate(_input_direction() * block.move_speed, delta)
	_face(_aim_direction(), delta, turn_speed)
	_update_upper_body_legs()
	if _try_roll() or _try_counter():
		return
	if _block_reaction_left > 0.0:
		_block_reaction_left -= delta
		if _block_reaction_left <= 0.0:
			model.play_upper(block.animation, 0.15)
	elif block.hold_time > 0.0:
		if _state_time >= block.hold_time and model.is_upper_playing():
			model.pause_upper()
	if not Input.is_action_pressed(&"block"):
		_change_state(State.NORMAL)


## Ноги, пока руки заняты верхним слоем (блок, перезарядка): стоят в боевой стойке
## или шагают. Идти можно в любую сторону — спиной вперёд шаг проигрывается задом наперёд.
func _update_upper_body_legs() -> void:
	var real := get_real_velocity()
	var horizontal := Vector3(real.x, 0.0, real.z)
	var speed := horizontal.length()
	if speed < 0.15:
		var stance := weapon.combat_idle if weapon else ANIM_IDLE
		if ranged_mode:
			stance = firearm.idle_animation
		model.play(stance, 0.2)
		return
	var backwards := horizontal.normalized().dot(_facing()) < -0.3
	model.play(ANIM_WALK, 0.2)
	var playback := clampf(speed / WALK_ANIM_SPEED, 0.5, 2.0)
	model.set_playback_speed(-playback if backwards else playback)


## Удар пришёлся в блок: урон по доле блока, отдача, вспышка. Щит изнашивается.
func _on_blocked(damage: int, away: Vector3, knockback: float) -> void:
	var block := _block_data()
	var passed := ceili(damage * block.damage_factor)
	if passed > 0:
		health.damage(passed)
	_set_horizontal_velocity(away * knockback * block.pushback)
	model.flash(Color(0.6, 0.8, 1.0, 0.5), 0.2)
	_shake_camera(0.25)
	_vibrate(0.3, 0.0, 0.12)

	if shield:
		shield_durability = maxi(shield_durability - damage, 0)
		shield_changed.emit(shield, shield_durability)
		if shield_durability == 0:
			_break_shield()
			return
		ShieldWear.apply(_shield_node, shield_durability, shield.max_durability)

	stamina.spend(damage * block.stamina_per_damage)
	if not stamina.has_any():
		_guard_break()
		return

	if block.hit_animation != &"":
		model.play_upper(block.hit_animation, 0.05, 1.0, true)
		_block_reaction_left = model.get_animation_length(block.hit_animation)


## В блоке кончилась выносливость: защита пробита, герой оглушён и открыт.
func _guard_break() -> void:
	model.flash(Color(1.0, 0.5, 0.1, 0.6), 0.3)
	_shake_camera(0.5)
	_vibrate(0.5, 0.7, 0.25)
	_change_state(State.HIT)
	_stun_time = GUARD_BREAK_STUN_TIME
	model.play(ANIM_SHIELD_BREAK if shield else ANIM_HIT, 0.05, 1.0, true)


## Щит разлетается в щепки, герой ненадолго оглушён.
func _break_shield() -> void:
	var at := _shield_node.global_position if _shield_node else global_position + Vector3.UP
	Debris.burst(get_parent(), at, SHIELD_DEBRIS_COLOR)
	_remove_shield_model()
	shield = null
	shield_changed.emit(null, 0)
	_shake_camera(0.7)
	_vibrate(0.6, 1.0, 0.3)
	_change_state(State.HIT)
	_stun_time = SHIELD_BREAK_STUN_TIME
	model.play(ANIM_SHIELD_BREAK, 0.05, 1.0, true)


# --- Контратака --------------------------------------------------------------


## Нажата контратака: если рядом враг в замахе — отводим удар и бьём в ответ,
## иначе — промах с короткой перезарядкой.
func _try_counter() -> bool:
	if not Input.is_action_just_pressed(&"counter") or _counter_cooldown_left > 0.0:
		return false
	# Ответный удар делается мечом — с пищалью в руках контратаки нет.
	if ranged_mode:
		return false
	if not stamina.try_spend(counter_stamina_cost):
		return false
	_attack_pending = false
	_combat_time_left = COMBAT_IDLE_TIME
	var target := _find_counter_target()
	_change_state(State.COUNTER)
	_counter_success = target != null
	if target:
		_face_instant(target.global_position - global_position)
		target.receive_counter(global_position)
		model.play(ANIM_DEFLECT, 0.02, 2.5, true)
		model.flash(Color(1.0, 0.95, 0.7, 0.7), 0.25)
		_shake_camera(0.3)
		_vibrate(0.6, 0.4, 0.15)
		_slow_motion()
	else:
		_counter_cooldown_left = COUNTER_COOLDOWN
		model.play(ANIM_DEFLECT, 0.05, 1.5, true)
	return true


func _update_counter(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if _counter_success and _state_time >= COUNTER_DEFLECT_TIME:
		var riposte := weapon.counter_attack if weapon and weapon.counter_attack else null
		if riposte == null:
			riposte = weapon.heavy_attack if weapon else null
		if riposte == null:
			_change_state(State.NORMAL)
			return
		_combo_index = RIPOSTE_INDEX
		_begin_attack(riposte, 1.0)
		model.play(riposte.animation, 0.05, riposte.anim_speed, true)
	elif not _counter_success and _state_time >= COUNTER_WHIFF_TIME:
		_change_state(State.NORMAL)


## Ближайший враг рядом, которого можно контратаковать.
func _find_counter_target() -> Enemy:
	var best: Enemy = null
	var best_distance := COUNTER_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_counterable():
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Короткое замедление времени — момент удачной контратаки.
func _slow_motion() -> void:
	Engine.time_scale = COUNTER_SLOWMO_SCALE
	await get_tree().create_timer(COUNTER_SLOWMO_TIME, true, false, true).timeout
	Engine.time_scale = 1.0


# --- Пищаль ------------------------------------------------------------------


## Заряжена — стреляем, пуста — перезаряжаем (если есть порох).
func _start_shoot_or_reload() -> void:
	if firearm_loaded:
		if stamina.try_spend(firearm.stamina_cost):
			_start_shoot()
	elif powder > 0:
		_start_reload()
	else:
		# Пороха нет — щелчок вхолостую: только мигнёт строка в интерфейсе.
		firearm_changed.emit(firearm, firearm_loaded, powder)


func _start_shoot() -> void:
	_change_state(State.SHOOT)
	_shot_fired = false
	_combat_time_left = COMBAT_IDLE_TIME
	_show_gun(true)
	_face_instant(_aim_direction())
	model.play(firearm.aim_animation, 0.08, 1.0, true)


func _update_shoot(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if not _shot_fired:
		_face(_aim_direction(), delta, turn_speed)
		if _try_roll():
			return
		if _state_time >= firearm.aim_time:
			_fire()
		return
	var recoil_end := firearm.aim_time + 0.8 * model.get_animation_length(firearm.shoot_animation)
	if _try_roll():
		return
	if _state_time >= recoil_end:
		_change_state(State.NORMAL)


## Выстрел: луч по направлению прицела на высоте груди — до стены или до врага.
func _fire() -> void:
	_shot_fired = true
	firearm_loaded = false
	firearm_changed.emit(firearm, firearm_loaded, powder)
	model.play(firearm.shoot_animation, 0.02, 1.0, true)

	var muzzle_node := _gun_node.find_child("Muzzle", true, false) as Node3D
	var muzzle := muzzle_node.global_position if muzzle_node else global_position + Vector3.UP * 1.4
	var ray := aim_ray()
	var victim := ray["enemy"] as Hurtbox
	var hit_enemy := victim != null
	if victim:
		victim.receive_hit(firearm.damage, global_position, firearm.knockback)
	GunshotFx.spawn(get_parent(), muzzle, ray["position"] as Vector3, ray["hit"] as bool)
	_shake_camera(0.45)
	_vibrate(0.6, 0.9, 0.2)
	if hit_enemy:
		_combo_index = -1
		_on_attack_landed(null)


## Луч выстрела по направлению прицела на высоте груди — до стены или до врага.
## Возвращает from, position (куда попадёт), hit (во что-то попал), enemy (Hurtbox врага или null).
func aim_ray() -> Dictionary:
	var max_range := firearm.max_range if firearm else 20.0
	var origin := global_position + Vector3.UP * AimGuide.LINE_HEIGHT
	var target := origin + _aim_direction() * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | Hurtbox.LAYER)
	query.collide_with_areas = true
	query.exclude = [get_rid(), hurtbox.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var enemy: Hurtbox = null
	var position := target
	if not result.is_empty():
		position = result["position"]
		var victim := result["collider"] as Hurtbox
		if victim and victim.team != hurtbox.team:
			enemy = victim
	return {"from": origin, "position": position, "hit": not result.is_empty(), "enemy": enemy}


## Сейчас видна линия прицела: пищаль в руках (или идёт прицеливание быстрого выстрела).
func is_aiming_firearm() -> bool:
	if firearm == null:
		return false
	if state == State.SHOOT:
		return not _shot_fired
	return ranged_mode and state == State.NORMAL


func _start_reload() -> void:
	_change_state(State.RELOAD)
	_show_gun(true)
	model.play_upper(firearm.reload_animation, 0.1, firearm.reload_anim_speed, true)


func _update_reload(delta: float) -> void:
	var dir := _input_direction()
	_accelerate(dir * firearm.reload_move_speed, delta)
	if dir != Vector3.ZERO:
		_face(dir, delta, turn_speed)
	_update_upper_body_legs()
	if _try_roll():
		return
	var duration := model.get_animation_length(firearm.reload_animation) / firearm.reload_anim_speed
	if _state_time >= duration:
		powder -= 1
		firearm_loaded = true
		firearm_changed.emit(firearm, firearm_loaded, powder)
		_change_state(State.NORMAL)


## В руке пищаль вместо меча (на время стрельбы и перезарядки).
func _show_gun(on: bool) -> void:
	if _gun_node:
		_gun_node.visible = on
	for node: Node in _weapon_nodes:
		(node as Node3D).visible = not on


# --- Кувырок и бомба ---------------------------------------------------------


## Начинает кувырок, если нажата кнопка и он не на перезарядке.
func _try_roll() -> bool:
	if not Input.is_action_just_pressed(&"roll") or _roll_cooldown_left > 0.0:
		return false
	if not stamina.try_spend(roll_stamina_cost):
		return false
	var dir := _input_direction()
	_roll_dir = dir.normalized() if dir != Vector3.ZERO else _facing()
	_face_instant(_roll_dir)
	_attack_pending = false
	_interact_pending = false
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
		bomb.launch(model.get_bone_global_position(&"RightHand"), _throw_target, 0.7)
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
	var block := _block_data()
	if state == State.BLOCK and block and _facing().dot(-away) >= block.min_dot:
		_on_blocked(damage, away, knockback)
		return

	health.damage(damage)
	model.flash(Color(1.0, 0.15, 0.1, 0.6), 0.3)
	_shake_camera(0.6)
	_vibrate(0.5, 0.8, 0.25)
	if health.is_dead():
		return
	_change_state(State.HIT)
	_stun_time = HIT_STUN_TIME
	_face_instant(-away)
	_set_horizontal_velocity(away * knockback)
	model.play(ANIM_HIT, 0.05, 1.0, true)


func _update_hit(delta: float) -> void:
	_accelerate(Vector3.ZERO, delta)
	if _state_time >= _stun_time:
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
		stamina.reset()
		_change_state(State.NORMAL)
		model.play(ANIM_IDLE, 0.0)


## Короткая заморозка мира при попадании — удар ощущается весомее.
func _on_attack_landed(_target: Hurtbox = null) -> void:
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
	# Верхний слой анимации нужен только в блоке и при перезарядке.
	var leaving_upper := state == State.BLOCK or state == State.RELOAD
	if leaving_upper and new_state != state:
		model.stop_upper()
	var leaving_gun := state == State.SHOOT or state == State.RELOAD
	if leaving_gun and new_state != State.SHOOT and new_state != State.RELOAD:
		# Быстрый выстрел с мечом в руках — пищаль убирается; в режиме пищали — остаётся.
		_show_gun(ranged_mode)
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


## Захваченная цель (или null).
func locked_target() -> Enemy:
	return _target_lock.target if _target_lock else null


## Направление прицела по земле — для захвата цели и прицела.
func get_aim_direction() -> Vector3:
	return _aim_direction()


## Ввод стика/WASD → направление на земле относительно камеры.
func camera_relative(input: Vector2) -> Vector3:
	return _camera_relative(input)


func _on_target_changed(target: Enemy) -> void:
	if camera:
		camera.focus_target = target


func _aim_point() -> Vector3:
	if aim_point_override != Vector3.INF:
		return aim_point_override
	# Захваченная цель важнее мыши и стика.
	if _target_lock and _target_lock.target:
		return _target_lock.target.global_position
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
