class_name WeaponData
extends Resource
## Оружие: модель в правой руке, серия лёгких ударов, сильный удар и блок.
## Новое оружие (двуручник, копьё) — это новый .tres в data/weapons/, код менять не нужно.

@export var display_name: String = "Меч"
## Модель в правой руке. Корень сцены задаёт хват относительно кости hand_r.
@export var main_hand: PackedScene
## Одноручное оружие можно носить со щитом.
@export var one_handed: bool = true

@export_group("Удары")
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
## Боевая стойка после удара.
@export var combat_idle: StringName = &"Sword_Idle"

@export_group("Блок")
@export var block: BlockData
