class_name Health
extends Node
## Здоровье персонажа или предмета.

signal changed(current: int, max_value: int)
signal died

@export var max_health: int = 100

var current: int = 0


func _ready() -> void:
	current = max_health


func is_dead() -> bool:
	return current <= 0


## Снимает здоровье. Возвращает, сколько реально снято.
func damage(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var dealt := mini(amount, current)
	current -= dealt
	changed.emit(current, max_health)
	if current == 0:
		died.emit()
	return dealt


func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


func reset() -> void:
	current = max_health
	changed.emit(current, max_health)
