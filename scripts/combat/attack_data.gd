class_name AttackData
extends Resource
## Один удар: анимация, урон и в какие моменты анимации он бьёт.
## Все «доли» — это доли длины анимации (0 — начало, 1 — конец).

@export var animation: StringName
@export var anim_speed: float = 1.0
@export var damage: int = 10
@export var knockback: float = 3.0
## Сколько выносливости стоит удар.
@export var stamina_cost: float = 10.0

@export_group("Тайминги")
## Окна удара: в это время зона удара активна. Несколько окон — несколько взмахов.
@export var hit_windows: Array[Vector2] = [Vector2(0.3, 0.6)]
## С какой доли можно перейти к следующему удару серии.
@export var combo_from: float = 0.6
## С какой доли удар можно прервать кувырком.
@export var cancel_from: float = 0.7
## На какой доле удар заканчивается (хвост анимации можно отрезать).
@export var end_at: float = 1.0
## Для заряжаемого удара: на этой доле анимация замирает, пока держат кнопку.
@export var charge_pose: float = 0.2

@export_group("Выпад")
## Сколько метров герой проходит вперёд во время удара.
@export var lunge_distance: float = 0.0
## В какой части анимации идёт выпад.
@export var lunge_window: Vector2 = Vector2(0.0, 0.3)

@export_group("Зона удара")
@export var hitbox_size: Vector3 = Vector3(1.8, 1.4, 1.6)
## Центр зоны относительно героя (+Z — вперёд).
@export var hitbox_offset: Vector3 = Vector3(0.0, 0.9, 0.9)


func is_in_hit_window(progress: float) -> bool:
	for window: Vector2 in hit_windows:
		if progress >= window.x and progress <= window.y:
			return true
	return false


## Длительность удара в секундах с учётом скорости анимации.
func duration(model: CharacterModel) -> float:
	return model.get_animation_length(animation) / anim_speed
