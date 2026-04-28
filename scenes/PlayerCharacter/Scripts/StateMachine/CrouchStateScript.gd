extends State

# tag: player state machine — crouch / stand-up (ceiling ray, transitions).

class_name CrouchState

var stateName : String = "Crouch"

var cR : CharacterBody3D

func enter(charRef : CharacterBody3D):
	cR = charRef
	
	verifications()
	
func verifications():
	cR.moveSpeed = cR.crouchSpeed
	cR.moveAccel = cR.crouchAccel
	cR.moveDeccel = cR.crouchDeccel
	
	cR.floor_snap_length = 1.0
	if cR.jumpCooldown > 0.0: cR.jumpCooldown = -1.0
	if cR.nbJumpsInAirAllowed < cR.nbJumpsInAirAllowedRef: cR.nbJumpsInAirAllowed = cR.nbJumpsInAirAllowedRef
	if cR.coyoteJumpCooldown < cR.coyoteJumpCooldownRef: cR.coyoteJumpCooldown = cR.coyoteJumpCooldownRef
	
func physics_update(delta : float):
	if cR is PlayerCharacter and (cR as PlayerCharacter).is_sitting:
		return
	checkIfFloor()
	
	applies(delta)
	
	cR.gravityApply(delta)
	
	inputManagement()
	
	move(delta)
	
func checkIfFloor():
	if !cR.is_on_floor() and !cR.is_on_wall():
		if cR.velocity.y < 0.0:
			transitioned.emit(self, "InairState")
	if cR.is_on_floor():
		if cR.jumpBuffOn:
			cR.bufferedJump = true
			cR.jumpBuffOn = false
			transitioned.emit(self, "JumpState")
			
func applies(delta : float):
	if cR.hitGroundCooldown > 0.0: cR.hitGroundCooldown -= delta
	
	cR.hitbox.shape.height = lerp(cR.hitbox.shape.height, cR.crouchHitboxHeight, cR.heightChangeSpeed * delta)
	cR.model.scale.y = lerp(cR.model.scale.y, cR.crouchModelHeight, cR.heightChangeSpeed * delta)
	
func inputManagement():
	if Input.is_action_just_pressed(cR.jumpAction):
		if !raycastVerification(): #if nothing block the player character when it will leaves the crouch state
			transitioned.emit(self, "JumpState")
			
	if cR.continiousCrouch: 
		#has to press run button once to run
		if Input.is_action_just_pressed(cR.crouchAction):
			if !raycastVerification():
				cR.walkOrRun = "WalkState"
				transitioned.emit(self, "WalkState")
	else:
		#has to continuously press crouch button to crouch
		if !Input.is_action_pressed(cR.crouchAction):
			if !raycastVerification():
				cR.walkOrRun = "WalkState"
				transitioned.emit(self, "WalkState")
			
func raycastVerification() -> bool:
	## True = blocked (cannot stand). Ignore hits on the player or their children — the ray can
	## self-intersect the capsule when `exclude_parent` is false, which trapped crouch on flat ground.
	if not cR.ceilingCheck.is_colliding():
		return false
	var collider: Object = cR.ceilingCheck.get_collider()
	if collider == null:
		return false
	if collider == cR:
		return false
	if collider is Node and cR.is_ancestor_of(collider as Node):
		return false
	return true
			
func move(delta : float):
	cR.inputDirection = Input.get_vector(cR.moveLeftAction, cR.moveRightAction, cR.moveForwardAction, cR.moveBackwardAction)
	cR.moveDirection = (cR.camHolder.global_basis * Vector3(cR.inputDirection.x, 0.0, cR.inputDirection.y)).normalized()
	
	if cR.moveDirection and cR.is_on_floor():
		cR.velocity.x = lerp(cR.velocity.x, cR.moveDirection.x * cR.moveSpeed, cR.moveAccel * delta)
		cR.velocity.z = lerp(cR.velocity.z, cR.moveDirection.z * cR.moveSpeed, cR.moveAccel * delta)
	else:
		cR.velocity.x = lerp(cR.velocity.x, 0.0, cR.moveDeccel * delta)
		cR.velocity.z = lerp(cR.velocity.z, 0.0, cR.moveDeccel * delta)
		
	if cR.hitGroundCooldown <= 0: cR.desiredMoveSpeed = cR.velocity.length()
	
	if cR.desiredMoveSpeed >= cR.maxSpeed: cR.desiredMoveSpeed = cR.maxSpeed
