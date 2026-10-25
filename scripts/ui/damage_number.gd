class_name DamageNumber
extends Label3D
## Всплывающая цифра урона над целью.


static func spawn(parent: Node, at: Vector3, value: int, color: Color = Color.WHITE) -> void:
	var label := DamageNumber.new()
	label.text = str(value)
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.05, 0.0)
	label.font_size = 72
	label.outline_size = 16
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.3, 0.3), 0.0, 0.0)

	var tween := label.create_tween().set_parallel()
	(
		tween
		. tween_property(label, "position:y", label.position.y + 1.2, 0.8)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
