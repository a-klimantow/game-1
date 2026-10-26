@tool
class_name CharacterModel
extends Node3D
## Собирает персонажа из частей Quaternius (одежда + голова + причёски) на одном скелете
## и проигрывает анимации из Universal Animation Library (части 1 и 2).
##
## Все части пака используют один скелет из 65 костей, поэтому меши частей
## просто переносятся на скелет одежды.

signal animation_finished(anim_name: StringName)

## Библиотеки анимаций; при совпадении имён побеждает первая.
const LIBRARIES: Array[AnimationLibrary] = [
	preload("res://assets/animations/UAL1_Standard.glb"),
	preload("res://assets/animations/UAL2_Standard.glb"),
]

## Общая библиотека из всех LIBRARIES, собирается один раз на всю игру.
static var _merged_library: AnimationLibrary

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
@export var default_animation: StringName = &"Idle"

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var _body: Node3D
var _overlay: StandardMaterial3D
var _flash_tween: Tween


func _ready() -> void:
	_rebuild()


## Включает анимацию. Если она уже играет и restart = false, ничего не меняет
## (скорость, заданную через set_playback_speed, тоже не сбрасывает).
func play(anim: StringName, blend: float = 0.15, speed: float = 1.0, restart: bool = false) -> void:
	if anim_player == null:
		return
	if not restart and anim_player.current_animation == anim:
		if not anim_player.is_playing():
			anim_player.play()
		return
	anim_player.speed_scale = 1.0
	anim_player.play(anim, blend, speed)
	if restart:
		anim_player.seek(0.0, true)


## Множитель скорости текущей анимации, например чтобы шаги совпадали со скоростью героя.
func set_playback_speed(value: float) -> void:
	if anim_player:
		anim_player.speed_scale = value


func pause() -> void:
	if anim_player:
		anim_player.pause()


func is_playing() -> bool:
	return anim_player != null and anim_player.is_playing()


func get_animation_length(anim: StringName) -> float:
	var library := get_library()
	if not library.has_animation(anim):
		return 0.0
	return library.get_animation(anim).length


static func get_library() -> AnimationLibrary:
	if _merged_library == null:
		_merged_library = AnimationLibrary.new()
		for library: AnimationLibrary in LIBRARIES:
			for anim_name: StringName in library.get_animation_list():
				if not _merged_library.has_animation(anim_name):
					_merged_library.add_animation(anim_name, library.get_animation(anim_name))
	return _merged_library


## Подсвечивает всю модель цветом. rise = false — вспышка, которая гаснет (попадание);
## rise = true — свечение, которое нарастает (предупреждение о замахе).
func flash(color: Color, duration: float, rise: bool = false) -> void:
	if _overlay == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	var target_alpha := color.a
	_overlay.albedo_color = Color(color, 0.0 if rise else target_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_overlay, "albedo_color:a", target_alpha if rise else 0.0, duration)


func clear_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	if _overlay:
		_overlay.albedo_color.a = 0.0


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

	# Общий полупрозрачный слой поверх всех мешей — для вспышек (flash).
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	for node: Node in skeleton.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _overlay

	anim_player = AnimationPlayer.new()
	add_child(anim_player, false, Node.INTERNAL_MODE_FRONT)
	anim_player.root_node = anim_player.get_path_to(_body)
	anim_player.add_animation_library(&"", get_library())
	anim_player.animation_finished.connect(
		func(anim: StringName) -> void: animation_finished.emit(anim)
	)
	if default_animation != &"":
		play(default_animation, 0.0)
