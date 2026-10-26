extends Node
## Автопилот для проверки героя: запускает арену и сам нажимает кнопки по расписанию,
## печатая в консоль, что происходит. Сценарий выбирается аргументом после «--»:
##   godot --headless res://tools/showcase.tscn -- movement
##   godot --headless res://tools/showcase.tscn -- combat

const ARENA: PackedScene = preload("res://scenes/levels/test_arena.tscn")

## [время в секундах, действие, нажать(true)/отпустить(false)]
const SCENARIOS: Dictionary = {
	"movement":
	[
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
	],
	# Подобрать щит, блокировать до поломки, взять второй щит, выбросить его.
	"shield":
	[
		[0.2, &"move_right", true],
		[0.62, &"interact", true],
		[0.67, &"interact", false],
		[1.3, &"move_right", false],
		[1.5, &"block", true],
		[14.0, &"block", false],
		[14.1, &"move_left", true],
		[15.6, &"move_left", false],
		[15.7, &"interact", true],
		[15.75, &"interact", false],
		[16.3, &"interact", true],
		[17.0, &"interact", false],
	],
	# Заряженный удар мечом, лёгкая серия, подбор щита, блок щитом, удар щитом с рывком.
	"weapons":
	[
		[0.2, &"move_right", true],
		[1.3, &"move_right", false],
		[2.2, &"attack", true],
		[3.2, &"attack", false],
		[6.0, &"attack", true],
		[6.05, &"attack", false],
		[6.3, &"attack", true],
		[6.35, &"attack", false],
		[6.7, &"attack", true],
		[6.75, &"attack", false],
		[8.5, &"move_left", true],
		[8.9, &"interact", true],
		[8.95, &"interact", false],
		[9.1, &"interact", true],
		[9.15, &"interact", false],
		[9.3, &"interact", true],
		[9.35, &"interact", false],
		[9.5, &"move_left", false],
		[9.7, &"interact", true],
		[9.75, &"interact", false],
		[9.9, &"block", true],
		[13.0, &"block", false],
		[13.2, &"heavy_attack", true],
		[13.25, &"heavy_attack", false],
		[14.5, &"attack", true],
		[14.55, &"attack", false],
		[14.8, &"attack", true],
		[14.85, &"attack", false],
		[16.2, &"heavy_attack", true],
		[16.25, &"heavy_attack", false],
	],
	# Подойти к одержимым, пропустить удар, постоять в блоке, потом бить и кинуть бомбу.
	"combat":
	[
		[0.2, &"move_right", true],
		[1.4, &"move_right", false],
		[6.0, &"block", true],
		[9.5, &"block", false],
		[9.8, &"attack", true],
		[9.85, &"attack", false],
		[10.1, &"attack", true],
		[10.15, &"attack", false],
		[10.5, &"attack", true],
		[10.55, &"attack", false],
		[12.6, &"attack", true],
		[12.65, &"attack", false],
		[12.9, &"attack", true],
		[12.95, &"attack", false],
		[13.3, &"attack", true],
		[13.35, &"attack", false],
		[15.5, &"throw", true],
		[15.55, &"throw", false],
	],
}
const DURATION: float = 18.5

var _timeline: Array = []
var _time: float = 0.0
var _next: int = 0
var _player: Player
var _log_timer: float = 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "movement"
	_timeline = SCENARIOS.get(scenario, SCENARIOS["movement"])
	print("Сценарий: ", scenario)
	var arena := ARENA.instantiate()
	add_child(arena)
	_player = arena.get_node("Player") as Player


func _physics_process(delta: float) -> void:
	_time += delta
	# Целимся в ближайшего врага — мышь в автопилоте не работает.
	var nearest := _nearest_enemy()
	if nearest:
		_player.aim_point_override = nearest.global_position
	while _next < _timeline.size():
		var step: Array = _timeline[_next]
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


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node3D
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## Печатает, что делает герой и ближайший одержимый.
func _log_state() -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var anim_player := _player.model.anim_player
	var line := (
		"%5.2fs  %-10s %-6s %3d hp  %-16s  v=%.1f%s"
		% [
			_time,
			_player.weapon.display_name if _player.weapon else "-",
			Player.State.keys()[_player.state],
			_player.health.current,
			anim_player.current_animation,
			speed,
			(
				(" неуязвим" if _player.is_invulnerable() else "")
				+ (" [рядом предмет]" if _player.pickup_candidate else "")
				+ (" щит %d" % _player.shield_durability if _player.shield else "")
			),
		]
	)
	var enemy := _nearest_possessed()
	if enemy:
		line += (
			"   | одержимый %-8s %2d hp  %.1f м"
			% [
				Possessed.State.keys()[enemy.state],
				enemy.health.current,
				enemy.global_position.distance_to(_player.global_position),
			]
		)
	print(line)


func _nearest_possessed() -> Possessed:
	var best: Possessed = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Possessed
		if enemy == null:
			continue
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best
