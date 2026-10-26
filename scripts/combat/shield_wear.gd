class_name ShieldWear
extends RefCounted
## Износ щита на глаз: чем меньше прочности, тем темнее и «обугленнее» модель.

const MAX_DARKNESS: float = 0.65


## Затемняет все меши модели щита по доле оставшейся прочности.
static func apply(shield_model: Node, durability: int, max_durability: int) -> void:
	var worn := 1.0 - clampf(float(durability) / maxf(max_durability, 1), 0.0, 1.0)
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(0.05, 0.03, 0.02, worn * MAX_DARKNESS)
	for node: Node in shield_model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = overlay if worn > 0.01 else null
