extends Node

enum dir {LEFT, RIGHT, UP, DOWN, TOPLEFT, TOPRIGHT, BOTLEFT, BOTRIGHT}

func dir_angle(direction: int) -> int:
	match direction:
		dir.LEFT: return -90
		dir.RIGHT: return 90
		dir.UP: return 0
		dir.DOWN: return 180
		dir.TOPLEFT: return -45
		dir.TOPRIGHT: return 45
		dir.BOTLEFT: return -135
		dir.BOTRIGHT: return 135
		_: return 0

enum DamageType {NONE, BEAM, BOMB, POWERBOMB, MISSILE, SUPERMISSILE, SCREWATTACK, SPEEDBOOSTER, CRUMBLE}
enum Upgrade {GRAPPLEBEAM, BEAM, BOMB, CHARGEBEAM, ETANK, GRAVITY, HIGHJUMP, ICEBEAM, MISSILE, MORPHBALL, PLASMABEAM, POWERBOMB, POWERGRIP, SCREWATTACK, SPACEJUMP, SPAZERBEAM, SPEEDBOOSTER, SPIDERBALL, SPRINGBALL, SUPERMISSILE, VARIA, WAVEBEAM, SCAN, XRAY}
var upgrade_data: Dictionary
var Visors: Array = [Upgrade.XRAY, Upgrade.SCAN]
enum Layers {ENEMY, PROJECTILE, SAMUS, WORLD, DOOR}

func _ready():
	upgrade_data = Global.load_json("res://scenes/objects/upgrade_pickup/upgrade_data.json")
