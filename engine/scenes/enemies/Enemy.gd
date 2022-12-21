extends KinematicBody2D
class_name Enemy

onready var AmmoPickupScene: PackedScene = preload("res://engine/scenes/objects/ammo_pickup/AmmoPickup.tscn")

export var id: String
onready var data: Dictionary = Data.data["damage_values"][id]
onready var health: float = data["health"]
onready var effective_types: Array = data["effective_types"] if "effective_types" in data else []
onready var ineffective_types: Array = data["ineffective_types"] if "ineffective_types" in data else []

func _ready():
	z_as_relative = false
	z_index = Enums.Layers.ENEMY
	Enums.add_node_to_group(self, Enums.Groups.ENEMY)
	material = preload("res://engine/resources/DissolveAndWhiten.tres").duplicate()
	material.set("shader_param/whitening_enabled", false)
	material.set("shader_param/whitening_value", 0.0)

func death(_type: int):
	var ammoPickup: AmmoPickup = AmmoPickupScene.instance()
	ammoPickup.spawn(Loader.Samus, data["ammo_drop_profile"], global_position)

func damage(type: int, amount: float, _impact_position: Vector2):
	
	if Loader.loaded_save.difficulty_data["ohko_enemies"]:
		health = 0
		death(type)
		return
	
	if health > 0 and (type in effective_types or not type in ineffective_types):
		health = max(0, health - amount)
		
		# DEBUG
		Notification.types["text"].instance().init("*Gasp* The enemy! " + str(amount), 2.0)
		
		if health == 0:
			death(type)
		else:
			material.set("shader_param/whitening_enabled", true)
			material.set("shader_param/whitening_value", 1.0)
			Global.wait(0.1, false, [material, "set", ["shader_param/whitening_enabled", false]])
#			material.set("shader_param/whitening_enabled", false)
