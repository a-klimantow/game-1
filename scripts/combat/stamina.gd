class_name Stamina
extends Node
## Выносливость: тратится на удары, кувырки, спринт, контратаки и удары в блок,
## восстанавливается после короткой паузы. Действие можно начать, пока есть хоть сколько-то
## выносливости (как в Dark Souls); если она кончилась — герой «выдохся»: восстановление
## начинается позже, а спринт недоступен, пока запас не наберётся снова.

signal changed(current: float, max_value: float)
## Попытка действия без выносливости — для подсказки в интерфейсе.
signal denied
## Выносливость кончилась.
signal exhausted

@export var max_stamina: float = 100.0
## Восстановление в секунду.
@export var regen_rate: float = 35.0
## Пауза после траты, прежде чем начнётся восстановление.
@export var regen_delay: float = 0.6
## Пауза, если выносливость кончилась полностью.
@export var exhausted_delay: float = 1.4
## После истощения спринт снова доступен, когда наберётся эта доля.
@export_range(0.0, 1.0) var recover_fraction: float = 0.3

var current: float = 0.0
## Множитель восстановления (например, в блоке восстанавливается медленнее).
var regen_multiplier: float = 1.0
var is_exhausted: bool = false

var _delay_left: float = 0.0


func _ready() -> void:
	current = max_stamina


func _physics_process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current < max_stamina:
		current = minf(current + regen_rate * regen_multiplier * delta, max_stamina)
		changed.emit(current, max_stamina)
	if is_exhausted and current >= max_stamina * recover_fraction:
		is_exhausted = false


func has_any() -> bool:
	return current > 0.0


## Тратит выносливость на действие. Если её нет совсем — действие не выполняется.
func try_spend(cost: float) -> bool:
	if not has_any():
		denied.emit()
		return false
	spend(cost)
	return true


## Тратит выносливость без проверки (спринт, удар в блок).
func spend(cost: float) -> void:
	if cost <= 0.0:
		return
	current = maxf(current - cost, 0.0)
	_delay_left = maxf(_delay_left, regen_delay)
	if current == 0.0 and not is_exhausted:
		is_exhausted = true
		_delay_left = exhausted_delay
		exhausted.emit()
	changed.emit(current, max_stamina)


func reset() -> void:
	current = max_stamina
	is_exhausted = false
	_delay_left = 0.0
	changed.emit(current, max_stamina)
