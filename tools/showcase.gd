extends Node
## Автопилот для проверки героя: запускает арену и сам нажимает кнопки по расписанию.
## Запуск с записью кадров:
##   godot --path . --write-movie /tmp/frames/f.png --fixed-fps 30 res://tools/showcase.tscn

const ARENA: PackedScene = preload("res://scenes/levels/test_arena.tscn")

## [время в секундах, действие, нажать(true)/отпустить(false)]
const TIMELINE: Array[Array] = [
	[0.3, &"move_down", true],
	[1.2, &"sprint", true],
	[2.2, &"sprint", false],
	[2.6, &"move_down", false],
	[3.0, &"move_up", true],
	[4.3, &"roll", true],
	[4.35, &"roll", false],
	[5.0, &"move_up", false],
	[5.3, &"attack", true],
	[5.35, &"attack", false],
	[5.6, &"attack", true],
	[5.65, &"attack", false],
	[6.0, &"attack", true],
	[6.05, &"attack", false],
	[8.5, &"block", true],
	[9.3, &"block", false],
	[9.6, &"throw", true],
	[9.65, &"throw", false],
]
const DURATION: float = 12.0

var _time: float = 0.0
var _next: int = 0
var _player: Player
var _log_timer: float = 0.0


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
	_log_timer -= delta
	if _log_timer <= 0.0:
		_log_timer = 0.25
		_log_state()
	if _time >= DURATION:
		get_tree().quit()


## Печатает в консоль, что делает герой: удобно проверять без окна (--headless).
func _log_state() -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var anim_player := _player.model.anim_player
	print(
		(
			"%5.2fs  %-7s  %-16s  скорость %.2f  анимация x%.2f%s"
			% [
				_time,
				Player.State.keys()[_player.state],
				anim_player.current_animation,
				speed,
				anim_player.speed_scale,
				"  неуязвим" if _player.is_invulnerable() else "",
			]
		)
	)
