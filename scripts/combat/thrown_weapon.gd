class_name ThrownWeapon
extends Node3D
## Брошенное оружие: летит по дуге остриём вперёд точно в точку прицела, ранит первого
## врага на пути и падает на землю — там его можно подобрать снова.

## Доля обычной гравитации: копьё летит почти прямо.
const GRAVITY_SCALE: float = 0.6
const MAX_FLIGHT_TIME: float = 3.0

var data: WeaponData
var velocity: Vector3 = Vector3.ZERO
## Команда бросившего: своих не ранит.
var team: StringName = &""
var _exclude: Array[RID] = []
## Насколько остриё впереди точки хвата — попадание считается по острию.
var _tip_length: float = 0.0
var _prev_tip: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## Бросок из точки хвата from так, чтобы дуга пришла точно в to.
static func launch(
	parent: Node,
	from: Vector3,
	to: Vector3,
	weapon: WeaponData,
	thrower_team: StringName,
	exclude: Array[RID]
) -> ThrownWeapon:
	var thrown := ThrownWeapon.new()
	thrown.data = weapon
	thrown.team = thrower_team
	thrown._exclude = exclude
	thrown.velocity = thrown._velocity_to(from, to)
	parent.add_child(thrown)
	# Узел — в точке хвата (там, где была рука), модель сдвинута так же, как в руке при броске.
	var grip := weapon.throw_grip.origin.y
	var model := weapon.main_hand.instantiate() as Node3D
	model.transform = Transform3D(Basis.IDENTITY, Vector3.DOWN * grip)
	thrown.add_child(model)
	thrown._tip_length = _model_top(model)
	thrown.global_position = from
	thrown._prev_tip = from
	thrown._orient()
	thrown.reset_physics_interpolation()
	return thrown


## Самая дальняя по оси Y точка модели (остриё) относительно узла.
static func _model_top(model: Node3D) -> float:
	var top := 0.0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := (model.transform * mesh.transform) * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top


func _physics_process(delta: float) -> void:
	_time += delta
	velocity.y -= _gravity * GRAVITY_SCALE * delta
	var to := global_position + velocity * delta
	var tip := to + velocity.normalized() * _tip_length
	# Луч по пути острия за кадр (в первый кадр — от руки до острия).
	var query := PhysicsRayQueryParameters3D.create(_prev_tip, tip, 1 | Hurtbox.LAYER)
	query.collide_with_areas = true
	query.exclude = _exclude
	_prev_tip = tip
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var victim := hit["collider"] as Hurtbox
		if victim and victim.team == team:
			# Своих пролетаем насквозь.
			_exclude.append(victim.get_rid())
		else:
			if victim:
				var source := global_position - velocity.normalized() * 2.0
				victim.receive_hit(data.throw_damage, source, data.throw_knockback)
			_land(hit["position"] as Vector3)
			return
	global_position = to
	_orient()
	if _time >= MAX_FLIGHT_TIME:
		_land(global_position)


## Скорость, с которой дуга из from приходит точно в to.
func _velocity_to(from: Vector3, to: Vector3) -> Vector3:
	var flight_time := maxf(from.distance_to(to) / data.throw_speed, 0.05)
	var gravity := _gravity * GRAVITY_SCALE
	return (to - from) / flight_time + Vector3.UP * 0.5 * gravity * flight_time


## Остриё (ось Y модели) — по направлению полёта.
func _orient() -> void:
	var dir := velocity.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	global_basis = Basis(side, dir, side.cross(dir))


## Упало: на этом месте (на земле) появляется предмет, который можно подобрать.
func _land(at: Vector3) -> void:
	var down := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 0.5, at + Vector3.DOWN * 20.0, 1
	)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	var ground := floor_hit["position"] as Vector3 if not floor_hit.is_empty() else at
	ItemPickup.drop_weapon(get_parent(), ground, data)
	queue_free()
