extends Node3D
## Стартовая сцена-заглушка: проверяет, что проект запускается.

@export var spin_speed: float = 1.0

@onready var _cube: MeshInstance3D = $Cube


func _process(delta: float) -> void:
	_cube.rotate_y(spin_speed * delta)
