class_name Bomb
extends RigidBody3D
## Самодельная пороховая бомба: летит по дуге, взрывается по фитилю или при попадании во врага.

@export var fuse_time: float = 1.3
@export var radius: float = 3.0
@export var damage: int = 30
@export var knockback: float = 8.0

var _time: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)


## Запускает бомбу из from так, чтобы через flight_time она упала в to.
func launch(from: Vector3, to: Vector3, flight_time: float) -> void:
	global_position = from
	reset_physics_interpolation()
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	linear_velocity = (to - from) / flight_time + Vector3.UP * 0.5 * gravity * flight_time
	angular_velocity = Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= fuse_time:
		_explode()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"enemies"):
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = Hurtbox.LAYER
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var hurtbox := result["collider"] as Hurtbox
		if hurtbox:
			hurtbox.receive_hit(damage, global_position, knockback)
	Explosion.spawn(get_parent(), global_position, radius)
	queue_free()
