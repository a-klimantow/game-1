class_name PlayerGun
extends Node
## Пищаль героя: смена оружия в руках, выстрел, перезарядка, прицел.
## Часть героя (Player): пользуется его внутренними методами — движением, поворотом,
## сменой состояния. Данные пищали (firearm, firearm_loaded, powder, ranged_mode)
## хранятся у героя — их читает интерфейс.

var _player: Player
## Модель пищали в правой руке (видна только с пищалью в руках, при выстреле и перезарядке).
var _gun_node: Node3D
var _shot_fired: bool = false


func setup(player: Player) -> void:
	_player = player


## Вешает пищаль (модель в руке появляется только при стрельбе и перезарядке).
func equip(data: FirearmData, loaded: bool) -> void:
	var p := _player
	if _gun_node:
		_gun_node.queue_free()
	p.firearm = data
	p.firearm_loaded = loaded
	_gun_node = p.model.attach_to_bone(data.model.instantiate() as Node3D, &"RightHand")
	show_gun(p.ranged_mode)
	p.firearm_changed.emit(p.firearm, p.firearm_loaded, p.powder)


## Берёт в руки пищаль (true) или меч (false). Пищаль остаётся в руках, пока не сменишь.
func set_ranged_mode(on: bool) -> void:
	var p := _player
	if on and p.firearm == null:
		return
	if on == p.ranged_mode:
		return
	p.ranged_mode = on
	p._attack_pending = false
	p._combat_time_left = Player.COMBAT_IDLE_TIME
	show_gun(on)
	p.ranged_mode_changed.emit(on)


## Смена оружия в руках по кнопкам. Возвращает true, если оружие сменили.
func update_switch() -> bool:
	var p := _player
	var want := p.ranged_mode
	if Input.is_action_just_pressed(&"switch_weapon"):
		want = not p.ranged_mode
	elif Input.is_action_just_pressed(&"select_melee"):
		want = false
	elif Input.is_action_just_pressed(&"select_firearm"):
		want = true
	if want == p.ranged_mode:
		return false
	set_ranged_mode(want)
	return want == p.ranged_mode


## Заряжена — стреляем, пуста — перезаряжаем (если есть порох).
func start_shoot_or_reload() -> void:
	var p := _player
	if p.firearm_loaded:
		if p.stamina.try_spend(p.firearm.stamina_cost):
			_start_shoot()
	elif p.powder > 0:
		_start_reload()
	else:
		# Пороха нет — щелчок вхолостую: только мигнёт строка в интерфейсе.
		p.firearm_changed.emit(p.firearm, p.firearm_loaded, p.powder)


func _start_shoot() -> void:
	var p := _player
	p._change_state(Player.State.SHOOT)
	_shot_fired = false
	p._combat_time_left = Player.COMBAT_IDLE_TIME
	show_gun(true)
	p._face_instant(p._aim_direction())
	p.model.play(p.firearm.aim_animation, 0.08, 1.0, true)


func update_shoot(delta: float) -> void:
	var p := _player
	p._accelerate(Vector3.ZERO, delta)
	if not _shot_fired:
		p._face(p._aim_direction(), delta, p.turn_speed)
		if p._try_roll():
			return
		if p._state_time >= p.firearm.aim_time:
			_fire()
		return
	var recoil := 0.8 * p.model.get_animation_length(p.firearm.shoot_animation)
	if p._try_roll():
		return
	if p._state_time >= p.firearm.aim_time + recoil:
		p._change_state(Player.State.NORMAL)


## Выстрел: луч по направлению прицела на высоте груди — до стены или до врага.
func _fire() -> void:
	var p := _player
	_shot_fired = true
	p.firearm_loaded = false
	p.firearm_changed.emit(p.firearm, p.firearm_loaded, p.powder)
	p.model.play(p.firearm.shoot_animation, 0.02, 1.0, true)

	var muzzle_node := _gun_node.find_child("Muzzle", true, false) as Node3D
	var muzzle := (
		muzzle_node.global_position if muzzle_node else p.global_position + Vector3.UP * 1.4
	)
	var ray := aim_ray()
	var victim := ray["enemy"] as Hurtbox
	if victim:
		victim.receive_hit(p.firearm.damage, p.global_position, p.firearm.knockback)
	GunshotFx.spawn(p.get_parent(), muzzle, ray["position"] as Vector3, ray["hit"] as bool)
	p._shake_camera(0.45)
	p._vibrate(0.6, 0.9, 0.2)
	if victim:
		p._combo_index = -1
		p._on_attack_landed(null)


## Луч прицела по направлению взгляда на высоте груди — до стены или до врага
## (max_range < 0 — дальность пищали). Возвращает from, position (куда попадёт),
## hit (во что-то попал), enemy (Hurtbox врага или null).
func aim_ray(max_range: float = -1.0) -> Dictionary:
	var p := _player
	if max_range < 0.0:
		max_range = p.firearm.max_range if p.firearm else 20.0
	var origin := p.global_position + Vector3.UP * AimGuide.LINE_HEIGHT
	var target := origin + p._aim_direction() * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | Hurtbox.LAYER)
	query.collide_with_areas = true
	query.exclude = [p.get_rid(), p.hurtbox.get_rid()]
	var result := p.get_world_3d().direct_space_state.intersect_ray(query)
	var enemy: Hurtbox = null
	var position := target
	if not result.is_empty():
		position = result["position"]
		var victim := result["collider"] as Hurtbox
		if victim and victim.team != p.hurtbox.team:
			enemy = victim
	return {"from": origin, "position": position, "hit": not result.is_empty(), "enemy": enemy}


## Сейчас видна линия прицела: пищаль в руках (или идёт прицеливание быстрого выстрела).
func is_aiming() -> bool:
	var p := _player
	if p.firearm == null:
		return false
	if p.state == Player.State.SHOOT:
		return not _shot_fired
	return p.ranged_mode and p.state == Player.State.NORMAL


func _start_reload() -> void:
	var p := _player
	p._change_state(Player.State.RELOAD)
	show_gun(true)
	p.model.play_upper(p.firearm.reload_animation, 0.1, p.firearm.reload_anim_speed, true)


func update_reload(delta: float) -> void:
	var p := _player
	var dir := p._input_direction()
	p._accelerate(dir * p.firearm.reload_move_speed, delta)
	if dir != Vector3.ZERO:
		p._face(dir, delta, p.turn_speed)
	p._update_upper_body_legs()
	if p._try_roll():
		return
	var anim_length := p.model.get_animation_length(p.firearm.reload_animation)
	if p._state_time >= anim_length / p.firearm.reload_anim_speed:
		p.powder -= 1
		p.firearm_loaded = true
		p.firearm_changed.emit(p.firearm, p.firearm_loaded, p.powder)
		p._change_state(Player.State.NORMAL)


## В руке пищаль вместо меча (on) или наоборот.
func show_gun(on: bool) -> void:
	if _gun_node:
		_gun_node.visible = on
	for node: Node in _player._weapon_nodes:
		(node as Node3D).visible = not on


## Герой выходит из выстрела или перезарядки: с мечом в руках пищаль убирается.
func on_state_changed(old_state: Player.State, new_state: Player.State) -> void:
	var gun_states: Array[Player.State] = [Player.State.SHOOT, Player.State.RELOAD]
	if old_state in gun_states and not new_state in gun_states:
		show_gun(_player.ranged_mode)
