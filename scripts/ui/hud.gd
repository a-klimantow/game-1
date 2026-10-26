class_name Hud
extends CanvasLayer
## Интерфейс поверх игры: здоровье героя со «следом» от урона, выносливость,
## прочность щита и снаряжение.

const STAMINA_COLOR := Color(1.0, 1.0, 1.0)
const STAMINA_EXHAUSTED_COLOR := Color(0.55, 0.55, 0.55)
const STAMINA_DENIED_COLOR := Color(1.6, 0.4, 0.3)

@export var player: Player
## Как быстро «след» догоняет полосу здоровья (доля полосы в секунду).
@export var trail_speed: float = 0.5

var _denied_tween: Tween

@onready var health_bar: ProgressBar = %HealthBar
@onready var trail_bar: ProgressBar = %TrailBar
@onready var health_text: Label = %HealthText
@onready var weapon_label: Label = %WeaponLabel
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var stamina_bar: ProgressBar = %StaminaBar


func _ready() -> void:
	if player == null:
		return
	player.health.changed.connect(_on_health_changed)
	player.weapon_changed.connect(func(_weapon: WeaponData) -> void: _refresh_equipment())
	player.shield_changed.connect(_on_shield_changed)
	_on_shield_changed(player.shield, player.shield_durability)
	_on_health_changed(player.health.current, player.health.max_health)
	trail_bar.value = health_bar.value
	player.stamina.changed.connect(_on_stamina_changed)
	player.stamina.denied.connect(_on_stamina_denied)
	_on_stamina_changed(player.stamina.current, player.stamina.max_stamina)


func _process(delta: float) -> void:
	if trail_bar.value > health_bar.value:
		var step := trail_bar.max_value * trail_speed * delta
		trail_bar.value = move_toward(trail_bar.value, health_bar.value, step)


func _on_health_changed(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	trail_bar.max_value = max_value
	health_bar.value = current
	# Лечение — след сразу подтягивается, урон — догоняет плавно.
	if current > trail_bar.value:
		trail_bar.value = current
	health_text.text = "%d / %d" % [current, max_value]


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current
	# Выдохся — полоса сереет, пока запас не восстановится.
	if _denied_tween == null or not _denied_tween.is_running():
		var exhausted := player.stamina.is_exhausted
		stamina_bar.modulate = STAMINA_EXHAUSTED_COLOR if exhausted else STAMINA_COLOR


## Попытка действия без выносливости — полоса мигает красным.
func _on_stamina_denied() -> void:
	if _denied_tween:
		_denied_tween.kill()
	stamina_bar.modulate = STAMINA_DENIED_COLOR
	_denied_tween = create_tween()
	_denied_tween.tween_property(stamina_bar, "modulate", STAMINA_EXHAUSTED_COLOR, 0.35)


func _on_shield_changed(shield: ShieldData, durability: int) -> void:
	shield_bar.visible = shield != null
	if shield:
		shield_bar.max_value = shield.max_durability
		shield_bar.value = durability
	_refresh_equipment()


func _refresh_equipment() -> void:
	var text := player.weapon.display_name if player.weapon else "Без оружия"
	if player.shield:
		text += " + " + player.shield.display_name
	weapon_label.text = text
