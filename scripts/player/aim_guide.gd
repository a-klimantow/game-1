class_name AimGuide
extends Node3D
## Прицел с пищалью в руках: линия выстрела от героя и метка на конце.
## Если линия упирается во врага — краснеет.

const IDLE_COLOR := Color(1.0, 0.9, 0.6, 0.35)
const ENEMY_COLOR := Color(1.0, 0.25, 0.2, 0.75)
## Высота, на которой рисуется линия (как у пули).
const LINE_HEIGHT: float = 1.2

var _player: Player
var _material: StandardMaterial3D
var _line: MeshInstance3D
var _line_mesh: CylinderMesh
var _reticle: MeshInstance3D


func setup(player: Player) -> void:
	_player = player
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.albedo_color = IDLE_COLOR

	_line_mesh = CylinderMesh.new()
	_line_mesh.top_radius = 0.012
	_line_mesh.bottom_radius = 0.012
	_line_mesh.material = _material
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.24
	ring.material = _material
	_reticle = MeshInstance3D.new()
	_reticle.mesh = ring
	_reticle.scale = Vector3(1.0, 0.2, 1.0)
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_reticle)
	visible = false


func _process(_delta: float) -> void:
	if _player == null:
		return
	visible = _player.is_aiming_firearm()
	if not visible:
		return
	var ray := _player.aim_ray()
	var from: Vector3 = ray["from"]
	var to: Vector3 = ray["position"]
	var on_enemy: bool = ray["enemy"] != null
	_material.albedo_color = ENEMY_COLOR if on_enemy else IDLE_COLOR

	# Линию начинаем чуть впереди героя, чтобы она не торчала из спины.
	var dir := (to - from).normalized()
	var start := from + dir * 0.5
	var length := start.distance_to(to)
	_line.visible = length > 0.05
	if _line.visible:
		_line_mesh.height = length
		_line.global_position = (start + to) * 0.5
		var side := dir.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		_line.global_basis = Basis(side, dir, side.cross(dir))

	# Метка — на земле под концом линии.
	_reticle.global_position = Vector3(to.x, 0.06, to.z)
	_reticle.rotate_y(0.05)
