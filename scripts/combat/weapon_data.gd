class_name WeaponData
extends Resource
## Оружие: модель в правой руке, серия лёгких ударов, сильный удар и блок.
## Новое оружие (двуручник, копьё) — это новый .tres в data/weapons/, код менять не нужно.

@export var display_name: String = "Меч"
## Модель в правой руке. Корень сцены задаёт хват относительно кости RightHand.
@export var main_hand: PackedScene
## Одноручное оружие можно носить со щитом.
@export var one_handed: bool = true

@export_group("Удары")
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
## Ответный удар после удачной контратаки (пусто — используется сильный удар).
@export var counter_attack: AttackData
## Боевая стойка после удара.
@export var combat_idle: StringName = &"Sword_Idle"

@export_group("Блок")
@export var block: BlockData

@export_group("Бросок")
## Анимация броска (Q / RB). Пусто — оружие не метают.
@export var throw_animation: StringName = &""
@export var throw_anim_speed: float = 1.0
## Поза прицеливания (держишь кнопку броска).
@export var throw_aim_animation: StringName = &""
## С какой секунды анимации броска начинать после прицеливания (поза замаха).
@export var throw_aim_pose_time: float = 0.0
## Дальность прицела броска, м.
@export var throw_range: float = 18.0
## Когда оружие вылетает из руки (секунды анимации).
@export var throw_release_time: float = 0.5
## На какой доле анимации бросок заканчивается.
@export var throw_end_at: float = 0.8
@export var throw_damage: int = 20
@export var throw_knockback: float = 5.0
## Скорость полёта, м/с.
@export var throw_speed: float = 22.0
@export var throw_stamina_cost: float = 15.0
## Хват на время броска — поверх обычного хвата (корня сцены модели).
@export var throw_grip: Transform3D = Transform3D.IDENTITY


func can_throw() -> bool:
	return throw_animation != &""
