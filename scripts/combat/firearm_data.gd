class_name FirearmData
extends Resource
## Огнестрел (пищаль): одиночный мощный выстрел и долгая перезарядка порохом.

@export var display_name: String = "Пищаль"
## Модель в правой руке. Корень сцены задаёт хват относительно RightHand,
## узел Muzzle — дуло (оттуда вспышка и дым).
@export var model: PackedScene
@export var damage: int = 35
## Отброс; 6 и больше — тяжёлый удар (сбивает даже посреди взмаха врага).
@export var knockback: float = 9.0
@export var max_range: float = 20.0
## Сколько длится прицеливание перед выстрелом.
@export var aim_time: float = 0.3
@export var stamina_cost: float = 10.0

@export_group("Перезарядка")
## Скорость анимации перезарядки: меньше — дольше (1.67 с при 1.0).
@export var reload_anim_speed: float = 0.6
## Скорость ходьбы во время перезарядки, м/с.
@export var reload_move_speed: float = 1.4

@export_group("Анимации")
## Стойка, когда пищаль в руках.
@export var idle_animation: StringName = &"Pistol_Idle"
@export var aim_animation: StringName = &"Pistol_Aim_Neutral"
@export var shoot_animation: StringName = &"Pistol_Shoot"
@export var reload_animation: StringName = &"Pistol_Reload"
