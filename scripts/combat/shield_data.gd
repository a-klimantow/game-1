class_name ShieldData
extends Resource
## Щит для левой руки: блок, удар щитом и запас прочности.
## Прочность конкретного щита хранится у героя или у предмета на земле, не здесь.

@export var display_name: String = "Деревянный щит"
## Модель. Корень сцены задаёт хват относительно кости hand_l.
@export var model: PackedScene
## Сколько урона щит выдерживает в блоке, прежде чем сломаться.
@export var max_durability: int = 60
@export var block: BlockData
## Сильный удар со щитом (заменяет сильный удар оружия).
@export var bash_attack: AttackData
