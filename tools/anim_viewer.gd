extends Node3D
## Просмотрщик анимаций: персонаж с выбранным оружием, список всех анимаций,
## скорость, пауза и перемотка. Помогает подобрать анимации и окна удара (доли)
## для data/weapons/*.tres. Запуск: открыть tools/anim_viewer.tscn и нажать F6.

const WEAPONS_DIR := "res://data/weapons/"
const SHIELD: ShieldData = preload("res://data/shields/wooden_shield.tres")

var _weapons: Array[WeaponData] = []
var _weapon_nodes: Array[Node] = []
var _shield_node: Node3D
var _current: StringName = &""

@onready var model: CharacterModel = $Model
@onready var anim_list: ItemList = %AnimList
@onready var weapon_select: OptionButton = %WeaponSelect
@onready var speed_slider: HSlider = %SpeedSlider
@onready var time_slider: HSlider = %TimeSlider
@onready var turn_slider: HSlider = %TurnSlider
@onready var info: Label = %Info
@onready var pause_button: Button = %PauseButton
@onready var shield_toggle: CheckBox = %ShieldToggle


func _ready() -> void:
	var names: Array[StringName] = []
	for anim_name: StringName in CharacterModel.get_library().get_animation_list():
		names.append(anim_name)
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	for anim_name: StringName in names:
		anim_list.add_item(anim_name)
	anim_list.item_selected.connect(_on_anim_selected)

	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		if file.ends_with(".tres"):
			var weapon := load(WEAPONS_DIR + file) as WeaponData
			if weapon:
				_weapons.append(weapon)
				weapon_select.add_item(weapon.display_name)
	weapon_select.add_item("Без оружия")
	weapon_select.item_selected.connect(_on_weapon_selected)
	_on_weapon_selected(0)

	speed_slider.value_changed.connect(func(value: float) -> void: model.set_playback_speed(value))
	time_slider.value_changed.connect(_on_time_scrubbed)
	turn_slider.value_changed.connect(func(value: float) -> void: model.rotation_degrees.y = value)
	pause_button.pressed.connect(_toggle_pause)
	shield_toggle.toggled.connect(_on_shield_toggled)


func _process(_delta: float) -> void:
	var player := model.anim_player
	if player == null or _current == &"":
		return
	var length := model.get_animation_length(_current)
	var position := player.current_animation_position if player.current_animation != "" else 0.0
	var progress := position / length if length > 0.0 else 0.0
	if not time_slider.has_focus():
		time_slider.set_value_no_signal(progress)
	info.text = (
		"%s\nдлина %.2f с   время %.2f с\nдоля %.2f  (окна удара задаются в долях)"
		% [_current, length, position, progress]
	)


func _on_anim_selected(index: int) -> void:
	_current = StringName(anim_list.get_item_text(index))
	model.play(_current, 0.1, 1.0, true)
	model.set_playback_speed(speed_slider.value)
	pause_button.text = "Пауза"


func _on_time_scrubbed(value: float) -> void:
	if _current == &"":
		return
	model.anim_player.seek(value * model.get_animation_length(_current), true)


func _toggle_pause() -> void:
	if model.is_playing():
		model.pause()
		pause_button.text = "Дальше"
	else:
		model.play(_current)
		pause_button.text = "Пауза"


func _on_weapon_selected(index: int) -> void:
	for node: Node in _weapon_nodes:
		node.queue_free()
	_weapon_nodes.clear()
	if index >= _weapons.size():
		return
	var weapon := _weapons[index]
	if weapon.main_hand:
		_weapon_nodes.append(
			model.attach_to_bone(weapon.main_hand.instantiate() as Node3D, &"hand_r")
		)


func _on_shield_toggled(enabled: bool) -> void:
	if _shield_node:
		_shield_node.queue_free()
		_shield_node = null
	if enabled:
		_shield_node = model.attach_to_bone(SHIELD.model.instantiate() as Node3D, &"hand_l")
