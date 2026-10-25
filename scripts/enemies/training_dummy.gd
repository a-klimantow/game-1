class_name TrainingDummy
extends StaticBody3D
## Соломенное чучело для тренировки: получает урон, качается от ударов,
## падает при нуле здоровья и через пару секунд встаёт.

@export var max_health: int = 100
@export var respawn_time: float = 3.0

var health: int = 0
var _tween: Tween

@onready var visual: Node3D = $Visual
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	health = max_health
	hurtbox.hit_received.connect(_on_hit_received)
	_update_label()


func _on_hit_received(damage: int, source_position: Vector3, knockback: float) -> void:
	if health <= 0:
		return
	health = maxi(health - damage, 0)
	_update_label()
	DamageNumber.spawn(
		get_parent(), global_position + Vector3.UP * 2.3, damage, Color(1.0, 0.85, 0.3)
	)

	var away := global_position - source_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	# Ось наклона перпендикулярна направлению удара.
	var axis := Vector3.UP.cross(away).normalized()

	if _tween:
		_tween.kill()
	_tween = create_tween()
	if health > 0:
		var tilt := deg_to_rad(clampf(knockback * 5.0, 10.0, 35.0))
		(
			_tween
			. tween_method(_set_tilt.bind(axis), tilt, 0.0, 0.8)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)
	else:
		(
			_tween
			. tween_method(_set_tilt.bind(axis), 0.0, deg_to_rad(80.0), 0.5)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_OUT)
		)
		_tween.tween_interval(respawn_time)
		(
			_tween
			. tween_method(_set_tilt.bind(axis), deg_to_rad(80.0), 0.0, 0.6)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		_tween.tween_callback(_respawn)


func _set_tilt(angle: float, axis: Vector3) -> void:
	visual.basis = Basis(axis, angle)


func _respawn() -> void:
	health = max_health
	_update_label()


func _update_label() -> void:
	var filled := ceili(10.0 * health / max_health)
	health_label.text = (
		"Чучело\n%s\n%d / %d" % ["█".repeat(filled) + "░".repeat(10 - filled), health, max_health]
	)
