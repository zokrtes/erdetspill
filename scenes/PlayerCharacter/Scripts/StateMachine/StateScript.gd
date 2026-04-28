extends Node

class_name State

## Emitted by concrete state scripts (Idle, Walk, Run, etc.); consumed by StateMachineScript.
@warning_ignore("unused_signal")
signal transitioned

func enter(_charReference : CharacterBody3D):
	#enter state
	pass
	
func exit():
	#exit state
	pass
	
func update(_delta : float):
	#process update
	pass
	
func physics_update(_delta : float):
	#physics_process update
	pass 
