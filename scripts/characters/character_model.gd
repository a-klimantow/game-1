@tool
class_name CharacterModel
extends Node3D
## Собирает персонажа из частей Quaternius (одежда + голова + причёски) на одном скелете
## и проигрывает анимации из общей библиотеки Universal Animation Library.
##
## Все части пака используют один скелет из 65 костей, поэтому меши частей
## просто переносятся на скелет одежды.

signal animation_finished(anim_name: StringName)

const ANIMATION_LIBRARY: AnimationLibrary = preload("res://assets/animations/UAL2_Standard.glb")

## Основа персонажа: одежда со скелетом (assets/characters/outfits).
@export var outfit: PackedScene:
	set(value):
		outfit = value
		_rebuild()

## Дополнительные части: голова, причёска, борода.
@export var parts: Array[PackedScene] = []:
	set(value):
		parts = value
		_rebuild()

## Анимация, которая играет сразу (и в редакторе тоже).
@export var default_animation: StringName = &"Idle_FoldArms"

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var _body: Node3D


func _ready() -> void:
	_rebuild()


func play(anim: StringName, blend: float = 0.15, speed: float = 1.0, restart: bool = false) -> void:
	if anim_player == null:
		return
	if not restart and anim_player.current_animation == anim:
		anim_player.speed_scale = 1.0
		if not anim_player.is_playing():
			anim_player.play()
		return
	anim_player.speed_scale = 1.0
	anim_player.play(anim, blend, speed)
	if restart:
		anim_player.seek(0.0, true)


func pause() -> void:
	if anim_player:
		anim_player.pause()


func is_playing() -> bool:
	return anim_player != null and anim_player.is_playing()


func get_animation_length(anim: StringName) -> float:
	if not ANIMATION_LIBRARY.has_animation(anim):
		return 0.0
	return ANIMATION_LIBRARY.get_animation(anim).length


## Прикрепляет узел (например, меч) к кости. Возвращает созданный BoneAttachment3D.
func attach_to_bone(node: Node3D, bone: StringName) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	attachment.add_child(node)
	return attachment


func get_bone_global_position(bone: StringName) -> Vector3:
	var idx := skeleton.find_bone(bone)
	if idx < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body:
		_body.free()
		_body = null
	if anim_player:
		anim_player.free()
		anim_player = null
	skeleton = null
	if outfit == null:
		return

	_body = outfit.instantiate() as Node3D
	# INTERNAL — собранная модель не сохраняется в сцену и не мешает в дереве редактора.
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	skeleton = _body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	for part: PackedScene in parts:
		if part == null:
			continue
		var part_root: Node = part.instantiate()
		for node: Node in part_root.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.get_parent().remove_child(mesh)
			mesh.owner = null
			skeleton.add_child(mesh)
			mesh.skeleton = NodePath("..")
		part_root.free()

	anim_player = AnimationPlayer.new()
	add_child(anim_player, false, Node.INTERNAL_MODE_FRONT)
	anim_player.root_node = anim_player.get_path_to(_body)
	anim_player.add_animation_library(&"", ANIMATION_LIBRARY)
	anim_player.animation_finished.connect(
		func(anim: StringName) -> void: animation_finished.emit(anim)
	)
	if default_animation != &"":
		play(default_animation, 0.0)
