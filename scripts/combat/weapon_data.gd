class_name WeaponData
extends Resource
## Оружие: модели в руках, серия лёгких ударов, сильный удар и блок.
## Новое оружие (двуручник, копьё) — это новый .tres в data/weapons/, код менять не нужно.

@export var display_name: String = "Меч"
## Модель в правой руке. Корень сцены задаёт хват относительно кости hand_r.
@export var main_hand: PackedScene
## Модель в левой руке (щит) или пусто. Хват — относительно hand_l.
@export var off_hand: PackedScene

@export_group("Удары")
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
## Боевая стойка после удара.
@export var combat_idle: StringName = &"Sword_Idle"

@export_group("Блок")
@export var block_animation: StringName = &"Sword_Block"
## Через сколько секунд анимация блока замирает в стойке (0 — не замирает, для циклических).
@export var block_hold_time: float = 0.35
## Анимация отдачи, когда удар пришёлся в блок (пусто — без неё).
@export var block_hit_animation: StringName = &""
## Какая доля урона проходит сквозь блок.
@export_range(0.0, 1.0) var block_damage_factor: float = 0.2
## Ширина защиты: косинус половины угла (0.34 ≈ ±70°, 0.5 = ±60°).
@export var block_min_dot: float = 0.34
## Скорость ходьбы в блоке, м/с (0 — стоит на месте).
@export var block_move_speed: float = 0.0
## Насколько сильно отталкивает при ударе в блок (доля отброса удара).
@export var block_pushback: float = 0.4
