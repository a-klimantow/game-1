class_name BlockData
extends Resource
## Как защищается оружие или щит.

@export var animation: StringName = &"Sword_Block"
## Через сколько секунд анимация блока замирает в стойке (0 — не замирает, для циклических).
@export var hold_time: float = 0.35
## Анимация отдачи, когда удар пришёлся в блок (пусто — без неё).
@export var hit_animation: StringName = &""
## Какая доля урона проходит сквозь блок.
@export_range(0.0, 1.0) var damage_factor: float = 0.2
## Ширина защиты: косинус половины угла (0.34 ≈ ±70°, 0.5 = ±60°).
@export var min_dot: float = 0.34
## Скорость ходьбы в блоке, м/с (0 — стоит на месте).
@export var move_speed: float = 0.0
## Насколько сильно отталкивает при ударе в блок (доля отброса удара).
@export var pushback: float = 0.4
## Сколько выносливости тратит каждая единица урона, принятая в блок.
## Если выносливость кончилась — блок пробит, герой ненадолго оглушён.
@export var stamina_per_damage: float = 1.5
## Во сколько раз медленнее восстанавливается выносливость, пока держишь блок.
@export_range(0.0, 1.0) var stamina_regen_multiplier: float = 0.4
