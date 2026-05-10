extends Node3D
# WEAPON_VIEWMODEL_CONTROLLER tag.
# tag: weaponId keys — Pistol 1, AssaultRifle 2, Shotgun 3, SniperRifle 4, RocketLauncher 5, GrusSkive 6 (see weaponResources .tres).

var weaponStack : Array[int] = [] #weapons current wielded by play char
var weaponList : Dictionary = {} #all weapons available in the game (key = weapon name, value = wepakn resource)
@export var weaponResources : Array[WeaponResource] #all weapon resources files
@export var startWeapons : Array[WeaponSlot] #the weapon the player character will start with

var cW = null #current weapon
var cWModel = null #current weapon model
var weaponIndex : int = 0

#weapon changes variables
var canChangeWeapons : bool = true
var canUseWeapon : bool = true

@export_group("Keybind variables")
@export var shoot_action : String
@export var reload_action : String
@export var weapon_wheel_up_action : String
@export var weapon_wheel_down_action : String

@onready var playChar : CharacterBody3D = $"../../../.."
@onready var cameraHolder : Node3D = %CameraHolder
@onready var cameraRecoilHolder : Node3D = %CameraRecoilHolder
@onready var camera : Camera3D = %Camera
@onready var weaponContainer : Node3D = %WeaponContainer
@onready var shootManager : Node3D = %ShootManager
@onready var reloadManager : Node3D = %ReloadManager
@onready var ammoManager : Node3D = %AmmunitionManager
@onready var animPlayer : AnimationPlayer = %AnimationPlayer
@onready var animManager : Node3D = %AnimationManager
@onready var audioManager : PackedScene = preload("../../Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal : PackedScene = preload("../../Weapons/Scenes/BulletDecalScene.tscn")
@onready var hud : CanvasLayer = %HUD
@onready var linkComponent : Node3D = %LinkComponent

func _ready():
	if not is_in_group("WeaponViewmodelController"):
		add_to_group("WeaponViewmodelController")
	initialize()
	
func initialize():
	for weapon in weaponResources:
		#create dict to refer weapons
		weaponList[weapon.weaponId] = weapon
		
	for weapo in weaponList.keys():
		#weaponsEmplacements[weapo] = weaponIndex
		cW = weaponList[weapo] #set each weapon to current, to acess properties useful to set up animations slicing and select correct weapon slot
		
		for weaponSlot in weaponContainer.get_children():
			if weaponSlot.weaponId == cW.weaponId: #id correspondant
				
				#if weapon is in the predetermined start weapons list
				for startWeapon in startWeapons:
					if startWeapon.weaponId == cW.weaponId: 
						weaponStack.append(cW.weaponId)
						
				cW.weaponSlot = weaponSlot #get weapon slot script ref from weapon list (allows to get access to model, attack point, ...)
				cWModel = cW.weaponSlot.model
				cWModel.visible = false
				
				forceAttackPointTransformValues(cW.weaponSlot.attackPoint)
				
				cW.bobPos = cW.position
				
	if weaponStack.size() > 0:
		#enable (equip and set up) the first weapon on the weapon stack
		enterWeapon(weaponStack[0])
	else:
		cW = null
		cWModel = null
		canUseWeapon = false
		canChangeWeapons = false

func exitWeapon(nextWeapon : int):
	#this function manage the first part of the weapon switching mechanic
	#in this part, the current weapon is disabled (unequiped and taked down)
	if nextWeapon != cW.weaponId:
		canChangeWeapons = false
		canUseWeapon = false
		if cW.isShooting: cW.isShooting = false
		if cW.isReloading:
			cW.isReloading = false
			if cWModel != null:
				_reset_all_mesh_children_visible(cWModel)
		
		if cW.unequipAnimName != "":
			animManager.playAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
		await get_tree().create_timer(cW.unequipTime).timeout
		
		cWModel.visible = false
		
		enterWeapon(nextWeapon)
	
func enterWeapon(nextWeapon : int):
	#this function manage the second part of the weapon switching mechanic
	#in this part, the next weapon is enabled (equiped and set up)
	cW = weaponList[nextWeapon]
	nextWeapon = 0
	cWModel = cW.weaponSlot.model
	cWModel.visible = true
	_reset_all_mesh_children_visible(cWModel)
	
	shootManager.getCurrentWeapon(cW)
	reloadManager.getCurrentWeapon(cW)
	animManager.getCurrentWeapon(cW, cWModel)
	
	weaponSoundManagement(cW.equipSound, cW.equipSoundSpeed)
	
	animPlayer.playback_default_blend_time = cW.animBlendTime
	
	if cW.equipAnimName != "":
		animManager.playAnimation("EquipAnim%s" % cW.weaponName, cW.equipAnimSpeed, false)
	await get_tree().create_timer(cW.equipTime).timeout
	
	if cW.isShooting: cW.isShooting = false
	if cW.isReloading: cW.isReloading = false
	canUseWeapon = true
	canChangeWeapons = true
	
func _process(_delta : float):
	if cW != null and cWModel != null and canUseWeapon:
		weaponInputs()
		
		reloadManager.autoReload()
		
	displayStats()
	_refresh_reserve_dependent_weapon_meshes()
	
func weaponInputs():
	if cW == null:
		return
	if Input.is_action_pressed(shoot_action): shootManager.shoot()
			
	if Input.is_action_just_pressed(reload_action): reloadManager.reload()
	
	if Input.is_action_just_pressed(weapon_wheel_up_action):
		if canChangeWeapons and !cW.isShooting and !cW.isReloading:
			weaponIndex = min(weaponIndex + 1, weaponStack.size() - 1) #from first element of weapon stack to last element 
			changeWeapon(weaponStack[weaponIndex])
			
	if Input.is_action_just_pressed(weapon_wheel_down_action):
		if canChangeWeapons and !cW.isShooting and !cW.isReloading:
			weaponIndex = max(weaponIndex - 1, 0) #from last element of weapon stack to first element 
			changeWeapon(weaponStack[weaponIndex])
		
func displayStats():
	if hud == null:
		return
	hud.displayWeaponStack(weaponStack.size())
	if cW == null or ammoManager == null:
		return
	hud.displayWeaponName(cW.weaponName)
	hud.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
	hud.displayTotalAmmo(ammoManager.ammoDict[cW.ammoType], cW.nbProjShotsAtSameTime)
	
func acquire_weapon_by_id(weapon_id: int) -> void:
	# tag: weaponStack — add purchased weapon and equip (KJIWI vendor).
	if not weaponList.has(weapon_id):
		push_warning("Unknown weapon id: %s" % weapon_id)
		return
	if weapon_id in weaponStack:
		return
	weaponStack.append(weapon_id)
	weaponIndex = weaponStack.size() - 1
	changeWeapon(weapon_id)
	_refresh_reserve_dependent_weapon_meshes()


func _refresh_reserve_dependent_weapon_meshes() -> void:
	if ammoManager == null:
		return
	var rocket_node := get_node_or_null("WeaponContainer/RocketLauncher/RocketMesh") as MeshInstance3D
	if rocket_node != null:
		var rocket_left: int = int(ammoManager.ammoDict.get("RocketAmmo", 0))
		rocket_node.visible = rocket_left > 0
	var grus_slot := get_node_or_null("WeaponContainer/GrusSkive") as Node3D
	if grus_slot != null:
		var grus_model := grus_slot.get_node_or_null("GrusSkiveModel") as Node3D
		if grus_model != null:
			var grus_left: int = int(ammoManager.ammoDict.get("GrusSkiveAmmo", 0))
			var show_grus: bool = grus_left > 0 and (6 in weaponStack)
			grus_model.visible = show_grus


func changeWeapon(nextWeapon : int):
	if cW == null:
		enterWeapon(nextWeapon)
		return
	if canChangeWeapons and !cW.isShooting and !cW.isReloading:
		exitWeapon(nextWeapon)
	else:
		push_error("Can't change weapon now")
		return 
	
func displayMuzzleFlash():
	#create a muzzle flash instance, and display it at the indicated point
	if cW.muzzleFlashRef != null:
		var muzzleFlashInstance = cW.muzzleFlashRef.instantiate()
		add_child(muzzleFlashInstance)
		muzzleFlashInstance.global_position = cW.weaponSlot.muzzleFlashSpawner.global_position
		muzzleFlashInstance.emitting = true
	else:
		push_error("%s doesn't have a muzzle flash reference" % cW.weaponName)
		return
		
func displayBulletHole(colliderPoint: Vector3, colliderNormal: Vector3, hit_collider: Node = null):
	var bulletDecalInstance = bulletDecal.instantiate()
	var parent_node: Node = get_tree().get_root()
	if hit_collider != null and hit_collider is Node3D:
		parent_node = hit_collider
	parent_node.add_child(bulletDecalInstance)
	bulletDecalInstance.global_position = colliderPoint

	# Choose up vector — if normal is nearly vertical, use FORWARD instead
	var up_vector: Vector3 = Vector3.UP
	if abs(colliderNormal.dot(Vector3.UP)) > 0.99:
		up_vector = Vector3.FORWARD

	bulletDecalInstance.look_at(colliderPoint - colliderNormal, up_vector)
	bulletDecalInstance.rotate_object_local(Vector3(1.0, 0.0, 0.0), 90)
	
func weaponSoundManagement(soundName : AudioStream, soundSpeed : float):
	var audioIns : AudioStreamPlayer3D = audioManager.instantiate()
	get_tree().get_root().add_child.call_deferred(audioIns)
	#makes sure the node is in the scene tree
	await get_tree().process_frame
	if audioIns.is_inside_tree():
		audioIns.global_transform = cW.weaponSlot.attackPoint.global_transform
		audioIns.bus = "Sfx"
		audioIns.pitch_scale = soundSpeed
		audioIns.stream = soundName
		audioIns.play()
	else:
		print("The sound can't be played, AudioStreamPlayer3D instance is not in the scene tree")
	
func forceAttackPointTransformValues(attackPoint : Marker3D):
	#reset the attack points rotation values, to ensure that the projectiles will be shot in the correct direction
	if attackPoint.rotation != Vector3.ZERO: attackPoint.rotation = Vector3.ZERO

func set_weapon_controls_enabled(enabled: bool):
	canUseWeapon = enabled
	canChangeWeapons = enabled
	if cW != null:
		if cW.isShooting:
			cW.isShooting = false
		if cW.isReloading:
			cW.isReloading = false

func set_weapon_visible(visible: bool):
	if visible:
		# Restore only current equipped viewmodel.
		hide_all_weapon_models()
		if cWModel != null:
			cWModel.visible = true
	else:
		hide_all_weapon_models()

func get_current_weapon_model() -> Node:
	return cWModel

func hide_all_weapon_models():
	for weapon_slot in weaponContainer.get_children():
		if weapon_slot != null and weapon_slot.model != null:
			weapon_slot.model.visible = false

func show_weapon_model(model: Node):
	if model != null and model is Node3D:
		model.visible = true
		_reset_all_mesh_children_visible(model)

func reset_current_weapon_mesh_visibility():
	if cWModel != null:
		_reset_all_mesh_children_visible(cWModel)

func _reset_all_mesh_children_visible(model: Node):
	if model == null:
		return
	for child in model.get_children():
		if child is MeshInstance3D:
			child.visible = true
