class_name WeaponPickup
extends Area3D
## Оружие на земле: парит и крутится. Подходишь — появляется подсказка,
## нажимаешь «подобрать» — герой берёт оружие, а своё кладёт на это место.

@export var weapon: WeaponData:
	set(value):
		weapon = value
		if is_node_ready():
			_refresh()
@export var spin_speed: float = 1.2

var _player: Player

@onready var display: Node3D = $Display
@onready var prompt: Label3D = $Prompt


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1  # слой «player»
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	InputDevice.device_changed.connect(func(_device: int) -> void: _refresh_prompt())
	display.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_refresh()


func _process(delta: float) -> void:
	display.rotate_y(spin_speed * delta)
	display.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.002) * 0.1


## Герой подбирает оружие: своё оставляет здесь же (обмен).
func take(player: Player) -> void:
	var old := player.weapon
	player.equip(weapon)
	if old:
		weapon = old
		global_position = Vector3(
			player.global_position.x, global_position.y, player.global_position.z
		)
		reset_physics_interpolation()
	else:
		if player.pickup_candidate == self:
			player.pickup_candidate = null
		queue_free()


func _refresh() -> void:
	for child: Node in display.get_children():
		child.queue_free()
	if weapon == null:
		return
	# Модели лежат «в руке» под углом хвата — здесь ставим их ровно: клинок вверх, щит рядом.
	if weapon.main_hand:
		var main := weapon.main_hand.instantiate() as Node3D
		main.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 0.0))
		display.add_child(main)
	if weapon.off_hand:
		var off := weapon.off_hand.instantiate() as Node3D
		off.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.15))
		display.add_child(off)
	_refresh_prompt()


func _refresh_prompt() -> void:
	if weapon == null:
		return
	var key := "Y" if InputDevice.is_gamepad() else "E"
	prompt.text = "%s — взять: %s" % [key, weapon.display_name]


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	_player = player
	player.pickup_candidate = self
	prompt.show()


func _on_body_exited(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	if player.pickup_candidate == self:
		player.pickup_candidate = null
	_player = null
	prompt.hide()
