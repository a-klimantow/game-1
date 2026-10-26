class_name HealthLabel
extends Label3D
## Надпись над головой: имя и полоска здоровья из символов.

const SEGMENTS: int = 10

@export var title: String = ""
@export var health: Health


func _ready() -> void:
	if health:
		health.changed.connect(func(_current: int, _max_value: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	if health == null:
		text = title
		return
	var filled := ceili(float(SEGMENTS) * health.current / health.max_health)
	var bar := "█".repeat(filled) + "░".repeat(SEGMENTS - filled)
	text = "%s\n%s" % [title, bar]
