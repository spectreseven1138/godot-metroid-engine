extends RoomPhysicsBody2D
class_name RoomPhysicsBody2DDamageable

signal damage(type, amount, impact_position)

func damage(type: int, amount: int, impact_position: Vector2):
	emit_signal("damage", type, amount, impact_position)
