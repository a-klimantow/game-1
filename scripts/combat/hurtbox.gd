class_name Hurtbox
extends Area3D
## Зона, по которой можно попасть. Владелец подписывается на hit_received.

signal hit_received(damage: int, source_position: Vector3, knockback: float)

## Слой физики 4 — «hurtbox» (см. Project Settings → Layer Names).
const LAYER: int = 1 << 3

## Чья это зона: удары своей команды по ней не проходят.
@export var team: StringName = &"enemy"


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive_hit(damage: int, source_position: Vector3, knockback: float) -> void:
	hit_received.emit(damage, source_position, knockback)
