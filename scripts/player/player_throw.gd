class_name PlayerThrow
extends Node
## Броски героя: пороховая бомба и метание оружия из рук (копьё) с прицеливанием.
## Часть героя (Player): пользуется его внутренними методами — движением, поворотом,
## сменой состояния.

const ANIM_THROW: StringName = &"OverhandThrow"
const THROW_SPEED: float = 1.2
## Момент выпуска бомбы, в секундах анимации броска.
const THROW_RELEASE_TIME: float = 0.55
## Скорость шага, пока целишься броском оружия.
const AIM_MOVE_SPEED: float = 1.5

var _player: Player
## Бомба или оружие уже вылетели из руки.
var _released: bool = false
var _bomb_target: Vector3 = Vector3.ZERO
## Идёт бросок оружия (а не бомбы): какое оружие.
var _thrown_weapon: WeaponData


func setup(player: Player) -> void:
	_player = player


## Можно начать бросок по кнопке: с метательным оружием в руках — его, иначе бомбу.
func can_start() -> bool:
	return _can_throw_weapon() or _player.bomb_scene != null


## Начинает бросок (кнопку уже нажали): прицеливание оружием или бросок бомбы.
func start() -> void:
	var p := _player
	if _can_throw_weapon():
		if p.stamina.try_spend(p.weapon.throw_stamina_cost):
			_start_aim()
	elif p.stamina.try_spend(p.throw_stamina_cost):
		_start_bomb()


func _can_throw_weapon() -> bool:
	var weapon := _player.weapon
	return (
		weapon != null
		and not _player.ranged_mode
		and weapon.can_throw()
		and weapon.main_hand != null
	)


func _start_bomb() -> void:
	var p := _player
	var offset := p._aim_point() - p.global_position
	offset.y = 0.0
	offset = offset.limit_length(p.throw_range)
	_bomb_target = p.global_position + offset
	_released = false
	_thrown_weapon = null
	p._combat_time_left = Player.COMBAT_IDLE_TIME
	p._face_instant(offset)
	p._change_state(Player.State.THROW)
	p.model.play(ANIM_THROW, 0.1, THROW_SPEED, true)


func update(delta: float) -> void:
	var p := _player
	p._accelerate(Vector3.ZERO, delta)
	if _thrown_weapon:
		_update_weapon_throw()
		return
	if not _released and p._state_time >= THROW_RELEASE_TIME / THROW_SPEED:
		_released = true
		var bomb := p.bomb_scene.instantiate() as Bomb
		p.get_parent().add_child(bomb)
		bomb.launch(p.model.get_bone_global_position(&"RightHand"), _bomb_target, 0.7)
	if _released and p._try_roll():
		return
	if p._state_time >= 0.85 * p.model.get_animation_length(ANIM_THROW) / THROW_SPEED:
		p._change_state(Player.State.NORMAL)


## Держишь бросок — оружие занесено, видна линия прицела; отпустил — бросок.
func _start_aim() -> void:
	var p := _player
	_thrown_weapon = p.weapon
	_released = false
	p._combat_time_left = Player.COMBAT_IDLE_TIME
	p._change_state(Player.State.THROW_AIM)
	p._set_weapon_grip(p.weapon.throw_grip)
	p.model.play_upper(p.weapon.throw_aim_animation, 0.15)


func update_aim(delta: float) -> void:
	var p := _player
	p._combat_time_left = Player.COMBAT_IDLE_TIME
	p._accelerate(p._input_direction() * AIM_MOVE_SPEED, delta)
	p._face(p._aim_direction(), delta, p.turn_speed)
	p._update_upper_body_legs()
	if p._try_roll():
		return
	if not Input.is_action_pressed(&"throw"):
		start_weapon_throw()


## Бросок с позы замаха: оружие вылетает в момент throw_release_time и летит в прицел.
## Без прицеливания тоже можно (автотесты): тогда бросок начинается сразу.
func start_weapon_throw() -> void:
	var p := _player
	_thrown_weapon = p.weapon
	_released = false
	p._face_instant(p._aim_direction())
	p._change_state(Player.State.THROW)
	p._set_weapon_grip(p.weapon.throw_grip)
	p.model.play(p.weapon.throw_animation, 0.1, p.weapon.throw_anim_speed, true)
	p.model.seek(p.weapon.throw_aim_pose_time)


func _update_weapon_throw() -> void:
	var p := _player
	var data := _thrown_weapon
	# Время анимации броска (она началась с позы замаха).
	var anim_time := data.throw_aim_pose_time + p._state_time * data.throw_anim_speed
	if not _released:
		p._face_instant(p._aim_direction())
		if anim_time >= data.throw_release_time:
			_release_weapon()
	elif p._try_roll():
		return
	if anim_time >= data.throw_end_at * p.model.get_animation_length(data.throw_animation):
		p._change_state(Player.State.NORMAL)


## Оружие вылетает из руки и летит в точку прицела: во врага на линии или в конец линии.
func _release_weapon() -> void:
	var p := _player
	_released = true
	var from := p.model.get_bone_global_position(&"RightHand")
	var target: Vector3 = aim_ray()["position"]
	var exclude: Array[RID] = [p.get_rid(), p.hurtbox.get_rid()]
	ThrownWeapon.launch(p.get_parent(), from, target, _thrown_weapon, p.hurtbox.team, exclude)
	p.unequip()
	p._shake_camera(0.2)


## Луч прицела броска оружия (как у пищали, но на дальность броска).
func aim_ray() -> Dictionary:
	var data := _thrown_weapon if _thrown_weapon else _player.weapon
	return _player.gun.aim_ray(data.throw_range if data else 20.0)


## Сейчас целимся броском оружия: оружие занесено и ещё не вылетело.
func is_aiming() -> bool:
	var state := _player.state
	if state == Player.State.THROW_AIM:
		return true
	return state == Player.State.THROW and _thrown_weapon != null and not _released


## Бросок оружия прерван до выпуска (кувырок, удар по герою) — хват возвращается обычный.
func on_state_changed(old_state: Player.State, new_state: Player.State) -> void:
	var throwing := old_state == Player.State.THROW_AIM or old_state == Player.State.THROW
	if not throwing or new_state == Player.State.THROW:
		return
	if _thrown_weapon and _player.weapon == _thrown_weapon:
		_player._set_weapon_grip(Transform3D.IDENTITY)
