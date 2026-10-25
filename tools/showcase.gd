extends Node
## Автопилот для проверки героя: запускает арену и сам нажимает кнопки по расписанию.
## Запуск с записью кадров:
##   godot --path . --write-movie /tmp/frames/f.png --fixed-fps 30 res://tools/showcase.tscn

const ARENA: PackedScene = preload("res://scenes/levels/test_arena.tscn")

## [время в секундах, действие, нажать(true)/отпустить(false)]
const TIMELINE: Array[Array] = [
	[0.5, &"move_up", true],
	[1.6, &"move_up", false],
	[1.8, &"attack", true],
	[1.85, &"attack", false],
	[2.1, &"attack", true],
	[2.15, &"attack", false],
	[2.5, &"attack", true],
	[2.55, &"attack", false],
	[5.0, &"block", true],
	[6.0, &"block", false],
	[6.3, &"move_left", true],
	[6.5, &"dash", true],
	[6.55, &"dash", false],
	[7.0, &"move_left", false],
	[7.5, &"throw", true],
	[7.55, &"throw", false],
]
const DURATION: float = 10.0

var _time: float = 0.0
var _next: int = 0
var _player: Player


func _ready() -> void:
	var arena := ARENA.instantiate()
	add_child(arena)
	_player = arena.get_node("Player") as Player
	var dummy := arena.get_node("Dummy1") as Node3D
	_player.aim_point_override = dummy.global_position


func _physics_process(delta: float) -> void:
	_time += delta
	while _next < TIMELINE.size():
		var step: Array = TIMELINE[_next]
		var at: float = step[0]
		if at > _time:
			break
		var action: StringName = step[1]
		var pressed: bool = step[2]
		if pressed:
			Input.action_press(action)
		else:
			Input.action_release(action)
		_next += 1
	if _time >= DURATION:
		get_tree().quit()
