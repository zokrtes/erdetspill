extends Node3D
class_name SimpleVision3D

signal GetSight(body : Node3D)
signal LostSight

@export var Enabled : bool = true
@export var LookUpGroup : String = "PlayerCharacter"

@export_category("Vision Area")
@export var Distance : float = 50.0
@export var BaseWidth : float = 10.0
@export var EndWidth : float = 30.0
@export var BaseHeight : float = 5.0
@export var EndHeight : float = 5.0
@export var BaseConeSize : float = 1.0
@export var VisionArea : CollisionShape3D

@export_category("Collision Detection")
@export var VisionCollisionMask : int = 2  # Set to detect layer 2

var vision : Area3D
var target : Node3D

func _ready() -> void:
	vision = Area3D.new()
	
	# Configure collision mask to detect layer 2
	vision.collision_mask = VisionCollisionMask
	
	# Optional: Set collision layer if needed (default is 1)
	vision.collision_layer = 1
	
	if not VisionArea:
		VisionArea = CollisionShape3D.new()
		VisionArea.shape = __BuildVisionShape()	
	vision.add_child(VisionArea)
	add_child(vision)
	
	# Optional debug: Print what layers we're detecting
	print("Vision collision mask: ", vision.collision_mask)

func _process(delta: float) -> void:
	if not Enabled:
		return
		
	if target:
		if not CheckSight(target):
			target = null
			emit_signal("LostSight")
	else:
		CheckOverlaping()

func CheckSight(sightTarget : Node3D) -> bool:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, sightTarget.global_position)
	
	# Exclude the vision area itself to avoid self-intersection
	query.exclude = [vision.get_rid()]
	
	var collision = space.intersect_ray(query)
	if collision:
		# Check if we hit the target or any parent (in case of complex hierarchy)
		var hit = collision.collider
		while hit:
			if hit == sightTarget:
				return true
			hit = hit.get_parent()
	return false

func CheckOverlaping():
	var overlapingBodies = vision.get_overlapping_bodies()
	var targetOverlap = overlapingBodies.filter(func(item : Node3D) : return item.is_in_group(LookUpGroup))
	if len(targetOverlap) > 0:
		if CheckSight(targetOverlap[0]):
			target = targetOverlap[0]
			emit_signal("GetSight", target)

func __BuildVisionShape() -> ConvexPolygonShape3D:
	var result = ConvexPolygonShape3D.new()
	var points = PackedVector3Array()
	
	# Fixed: Use BaseWidth instead of BaseHeight for width dimensions
	points.append(Vector3(0, 0, 0))
	points.append(Vector3(BaseWidth/2, 0, -BaseConeSize))
	points.append(Vector3(EndWidth/2, 0, -Distance))
	points.append(Vector3(-(BaseWidth/2), 0, -BaseConeSize))
	points.append(Vector3(-(EndWidth/2), 0, -Distance))
	points.append(Vector3(0, BaseHeight, 0))	
	points.append(Vector3(BaseWidth/2, BaseHeight, -BaseConeSize))
	points.append(Vector3(EndWidth/2, BaseHeight, -Distance))
	points.append(Vector3(-(BaseWidth/2), BaseHeight, -BaseConeSize))
	points.append(Vector3(-(EndWidth/2), BaseHeight, -Distance))	    
	result.points = points
	return result
