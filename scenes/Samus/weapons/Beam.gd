extends SamusWeapon

var current_types: = []
onready var sprite: AnimatedSprite = ProjectileNode.get_node("Sprite")
onready var sprite_chargebeam: AnimatedSprite = ProjectileNode.get_node("SpriteChargebeam")

func _ready():
	Loader.Save.connect("value_set", self, "save_value_set")
	set_types()

func set_types():
	
	var types = []
	for type in Enums.UpgradeTypes["beam"]:
		if type != Enums.Upgrade.BEAM and Samus.is_upgrade_active(type):
			types.append(type)
	types.sort()
	current_types = types
	
	var animation = ""
	if len(current_types) == 0:
		animation = "b"
	else:
		for type in current_types:
			animation += Enums.Upgrade.keys()[type][0].to_lower()
	
	sprite.play(animation)
	sprite_chargebeam.play(animation)
	set_collision()
	
	ProjectileNode.get_node("IceParticles").emitting = Enums.Upgrade.ICEBEAM in current_types
	ProjectileNode.get_node("Trail").texture = sprite_chargebeam.frames.get_frame(animation, 0)

func set_collision():
	var texture = sprite.frames.get_frame(sprite.animation, 0)
	ProjectileNode.get_node("CollisionShape2D").shape.extents = texture.get_size()/2
	ProjectileNode.get_node("CollisionShape2D").position = sprite.position
	

func save_value_set(keys: Array, _value):
	if len(keys) != 4 or keys[0] != "samus" or keys[1] != "upgrades" or not keys[2] is int:
		return
	set_types()

func get_base_type(chargebeam: bool) -> int:
	var ret: int
	for type in [Enums.Upgrade.ICEBEAM, Enums.Upgrade.PLASMABEAM, Enums.Upgrade.WAVEBEAM]:
		if type in current_types:
			ret = type
			break
	if not ret:
		if chargebeam and Samus.is_upgrade_active(Enums.Upgrade.CHARGEBEAM):
			ret = Enums.Upgrade.CHARGEBEAM
		else:
			ret = Enums.Upgrade.BEAM
	return ret

func get_fire_object(pos: Position2D, chargebeam_damage_multiplier):
	if Cooldown.time_left > 0:
		return null
	
	sprite.visible = chargebeam_damage_multiplier == null
	sprite_chargebeam.visible = chargebeam_damage_multiplier != null
	
	var projectile_data = {"types": current_types.duplicate(), "rotation": pos.rotation, "base_type": get_base_type(chargebeam_damage_multiplier!=null)}
	
	var projectiles = []
	if Enums.Upgrade.SPAZERBEAM in current_types:
		for i in range(3):
			var projectile = ProjectileNode.duplicate()
			projectile_data["position"] = i
			projectile.init(self, pos, chargebeam_damage_multiplier, projectile_data.duplicate())
			projectile.affected_by_world = not Enums.Upgrade.WAVEBEAM in current_types
			projectiles.append(projectile)
			if i != 1:
				projectile.get_node("IceParticles").emitting = false
		
		if not Enums.Upgrade.WAVEBEAM in current_types:
#			Engine.time_scale = 0.25
			projectiles[0].position += 10*Vector2.LEFT.rotated(pos.rotation)
			projectiles[2].position += 10*Vector2.RIGHT.rotated(pos.rotation)
			
			var sprite_path = "SpriteChargebeam" if chargebeam_damage_multiplier != null else "Sprite"
			
			$Tween.interpolate_property(projectiles[0].get_node(sprite_path), "offset:y", 10, 0, 0.1)
			$Tween.interpolate_property(projectiles[2].get_node(sprite_path), "offset:y", -10, 0, 0.1)
			$Tween.start()
	else:
		var projectile: SamusKinematicProjectile = ProjectileNode.duplicate()
		projectile.init(self, pos, chargebeam_damage_multiplier, projectile_data)
		projectile.affected_by_world = not Enums.Upgrade.WAVEBEAM in current_types
		projectiles = [projectile]
	
	for projectile in projectiles:
		projectile.get_node("IceParticles").preprocess = randf()*2
	projectiles[0].burst_start(true, Enums.Upgrade.keys()[projectile_data["base_type"]] + " start")
	return projectiles

func offset(object, offset: Vector2):
	object.position += offset

func projectile_physics_process(projectile: SamusKinematicProjectile, collision: KinematicCollision2D, delta: float):
	var types = projectile.data["types"]
	if Enums.Upgrade.WAVEBEAM in types:
		if Enums.Upgrade.SPAZERBEAM in types:
			if projectile.data["position"] != 1:
				var y = -6*sin(0.075*projectile.travel_distance)*(projectile.data["position"]-1)
				projectile.position += Vector2(y, 0).rotated(projectile.data["rotation"])*delta*60
				projectile.rotation = Vector2(10, y).rotated(projectile.data["rotation"]).angle()
		else:
			var y = -4.5*cos(0.1*projectile.travel_distance)
			projectile.position += Vector2(y, 0).rotated(projectile.data["rotation"])*delta*60
			projectile.rotation = Vector2(10, y).rotated(projectile.data["rotation"]).angle()
			
	if collision:
		if (collision.collider.get_collision_layer_bit(19) and not Enums.Upgrade.WAVEBEAM in types) or (collision.collider.get_collision_layer_bit(2) and not Enums.Upgrade.PLASMABEAM in types):
			projectile.visible = false
			projectile.moving = false
			
			yield(projectile.burst_end(true, Enums.Upgrade.keys()[projectile.data["base_type"]] + " end"), "completed")
			projectile.queue_free()
