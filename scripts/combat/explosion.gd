class_name Explosion
extends Node3D
## Вспышка взрыва: огненная сфера и свет, которые быстро гаснут.


static func spawn(parent: Node, at: Vector3, radius: float) -> void:
	var explosion := Explosion.new()
	parent.add_child(explosion)
	explosion.global_position = at
	explosion._play(radius)


func _play(radius: float) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.62, 0.2, 0.85)
	var sphere := SphereMesh.new()
	sphere.material = material
	var fireball := MeshInstance3D.new()
	fireball.mesh = sphere
	fireball.scale = Vector3.ONE * 0.2
	fireball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fireball)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 10.0
	light.omni_range = radius * 3.0
	light.position.y = 0.5
	add_child(light)

	var tween := create_tween().set_parallel()
	(
		tween
		. tween_property(fireball, "scale", Vector3.ONE * radius * 2.0, 0.25)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(light, "light_energy", 0.0, 0.45)
	tween.chain().tween_callback(queue_free)
