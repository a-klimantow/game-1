class_name PlayerCounter
extends Node
## Контратака героя: если рядом враг в замахе («!» над ним) — отвести удар и ударить
## в ответ, иначе — промах с короткой перезарядкой.
## Часть героя (Player): пользуется его внутренними методами — движением, поворотом,
## сменой состояния, ударами.

## Дальность поиска врага, длительность отведения удара перед ответом,
## длительность и перезарядка промаха, замедление времени при успехе.
const RANGE: float = 2.5
const DEFLECT_TIME: float = 0.2
const WHIFF_TIME: float = 0.4
const COOLDOWN: float = 0.6
const SLOWMO_SCALE: float = 0.3
const SLOWMO_TIME: float = 0.3
const ANIM_DEFLECT: StringName = &"Sword_Block"

## Контратака удалась (ответный удар ещё впереди) — герой неуязвим.
var success: bool = false

var _player: Player
var _cooldown_left: float = 0.0


func setup(player: Player) -> void:
	_player = player


func tick(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## Нажата контратака: отводим удар врага рядом или промахиваемся. true — началась.
func try_start() -> bool:
	var p := _player
	if not Input.is_action_just_pressed(&"counter") or _cooldown_left > 0.0:
		return false
	# Ответный удар делается мечом — с пищалью в руках контратаки нет.
	if p.ranged_mode:
		return false
	if not p.stamina.try_spend(p.counter_stamina_cost):
		return false
	p._attack_pending = false
	p._combat_time_left = Player.COMBAT_IDLE_TIME
	var target := _find_target()
	p._change_state(Player.State.COUNTER)
	success = target != null
	if target:
		p._face_instant(target.global_position - p.global_position)
		target.receive_counter(p.global_position)
		p.model.play(ANIM_DEFLECT, 0.02, 2.5, true)
		p.model.flash(Color(1.0, 0.95, 0.7, 0.7), 0.25)
		p._shake_camera(0.3)
		p._vibrate(0.6, 0.4, 0.15)
		_slow_motion()
	else:
		_cooldown_left = COOLDOWN
		p.model.play(ANIM_DEFLECT, 0.05, 1.5, true)
	return true


func update(delta: float) -> void:
	var p := _player
	p._accelerate(Vector3.ZERO, delta)
	if success and p._state_time >= DEFLECT_TIME:
		var weapon := p.weapon
		var riposte := weapon.counter_attack if weapon and weapon.counter_attack else null
		if riposte == null:
			riposte = weapon.heavy_attack if weapon else null
		if riposte == null:
			p._change_state(Player.State.NORMAL)
			return
		p._combo_index = Player.RIPOSTE_INDEX
		p._begin_attack(riposte, 1.0)
		p.model.play(riposte.animation, 0.05, riposte.anim_speed, true)
	elif not success and p._state_time >= WHIFF_TIME:
		p._change_state(Player.State.NORMAL)


## Ближайший враг рядом, которого можно контратаковать.
func _find_target() -> Enemy:
	var best: Enemy = null
	var best_distance := RANGE
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_counterable():
			continue
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Короткое замедление времени — момент удачной контратаки.
func _slow_motion() -> void:
	Engine.time_scale = SLOWMO_SCALE
	await get_tree().create_timer(SLOWMO_TIME, true, false, true).timeout
	Engine.time_scale = 1.0
