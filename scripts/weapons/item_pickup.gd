class_name ItemPickup
extends Area3D
## Предмет на земле: оружие или щит. Парит и крутится; подходишь — подсказка,
## нажимаешь «подобрать» — герой берёт его. Оружие меняется на своё (своё остаётся здесь),
## щит берётся в левую руку, если оружие одноручное.

const SCENE_PATH := "res://scenes/weapons/item_pickup.tscn"

## Оружие на земле (или пусто, если здесь щит).
@export var weapon: WeaponData:
	set(value):
		weapon = value
		_refresh_if_ready()
## Щит на земле (или пусто, если здесь оружие).
@export var shield: ShieldData:
	set(value):
		shield = value
		_refresh_if_ready()
## Прочность щита; -1 — новый (полная прочность).
@export var durability: int = -1
@export var spin_speed: float = 1.2

var _player: Player

@onready var display: Node3D = $Display
@onready var prompt: Label3D = $Prompt


## Кладёт на землю выброшенный щит с его прочностью.
static func drop_shield(parent: Node, at: Vector3, data: ShieldData, left: int) -> ItemPickup:
	var pickup := (load(SCENE_PATH) as PackedScene).instantiate() as ItemPickup
	pickup.shield = data
	pickup.durability = left
	parent.add_child(pickup)
	pickup.global_position = at
	return pickup


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1  # слой «player»
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	InputDevice.device_changed.connect(func(_device: int) -> void: _refresh_prompt())
	display.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if shield and durability < 0:
		durability = shield.max_durability
	_refresh()


func _process(delta: float) -> void:
	display.rotate_y(spin_speed * delta)
	display.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.002) * 0.1


## Можно ли герою сейчас взять этот предмет.
func can_take(player: Player) -> bool:
	if shield:
		return player.weapon == null or player.weapon.one_handed
	return weapon != null


func take(player: Player) -> void:
	if not can_take(player):
		return
	if shield:
		var old_shield := player.shield
		var old_durability := player.shield_durability
		player.equip_shield(shield, durability)
		if old_shield:
			_become_shield(old_shield, old_durability, player)
		else:
			_consume(player)
	else:
		var old_weapon := player.weapon
		player.equip(weapon)
		if old_weapon:
			weapon = old_weapon
			_move_to(player)
		else:
			_consume(player)
	_refresh_prompt()


func _become_shield(data: ShieldData, left: int, player: Player) -> void:
	durability = left
	shield = data
	_move_to(player)


func _move_to(player: Player) -> void:
	global_position = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	reset_physics_interpolation()


func _consume(player: Player) -> void:
	if player.pickup_candidate == self:
		player.pickup_candidate = null
	queue_free()


func _refresh_if_ready() -> void:
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	for child: Node in display.get_children():
		child.queue_free()
	# Модели сохранены «в руке» под углом хвата — здесь ставим их ровно.
	var scene: PackedScene = shield.model if shield else (weapon.main_hand if weapon else null)
	if scene:
		var item := scene.instantiate() as Node3D
		var offset := Vector3.ZERO if shield else Vector3(0.0, -0.4, 0.0)
		item.transform = Transform3D(Basis.IDENTITY, offset)
		display.add_child(item)
		if shield:
			ShieldWear.apply(item, durability, shield.max_durability)
	_refresh_prompt()


func _refresh_prompt() -> void:
	var key := "Y" if InputDevice.is_gamepad() else "E"
	if shield:
		var left := durability if durability >= 0 else shield.max_durability
		prompt.text = (
			"%s — взять: %s (%d/%d)" % [key, shield.display_name, left, shield.max_durability]
		)
		if _player and not can_take(_player):
			prompt.text = "%s\nнужно одноручное оружие" % shield.display_name
	elif weapon:
		prompt.text = "%s — взять: %s" % [key, weapon.display_name]


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	_player = player
	player.pickup_candidate = self
	_refresh_prompt()
	prompt.show()


func _on_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	if player.pickup_candidate == self:
		player.pickup_candidate = null
	_player = null
	prompt.hide()
