class_name Hitbox
extends Area3D
## Зона удара. Пока активна, бьёт каждый Hurtbox внутри себя один раз за взмах.

@export var damage: int = 10
@export var knockback: float = 3.0

var active: bool = false:
	set(value):
		if value and not active:
			_already_hit.clear()
		active = value

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hurtbox.LAYER
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area: Area3D in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox in _already_hit:
			continue
		_already_hit.append(hurtbox)
		hurtbox.receive_hit(damage, global_position, knockback)
