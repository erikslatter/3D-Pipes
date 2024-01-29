extends Node3D

@export var previousPipe:Node3D
@export var pipeVariants:Array[String]
@export var worldBounds:Vector3
@export var pipeMaterial:StandardMaterial3D
@export var pipeCountToTriggerColorChange:int
var recursionLimit:int = 10

var recursions:int = 0
var pipeCount = 0

func _ready():
	$Timer.start()
	
func _pipeStep():
	# Choose variant randomly & instantiate it
	var variantIndex = randi() % (pipeVariants.size()-1)
	# If we have >1 recursion (problem solving 'mode'), unlock the U-turn pipe
	if (recursions > 0):
		variantIndex = randi() % (pipeVariants.size())
		
	var variantScene = load("res://" + pipeVariants[variantIndex])
	var instanced_pipe = variantScene.instantiate()
	add_child(instanced_pipe)
	
	for child in instanced_pipe.get_children():
		if child is GeometryInstance3D:
			print("found GeometryInstance3D in instanced pipe, swapping mat")
			child.material_override = pipeMaterial
	
	# Connect pipe inlet to previous pipe outlet (position + rotation)
	instanced_pipe.global_transform = previousPipe.global_transform * \
								previousPipe.get_node('PipeOutlet').transform *\
								instanced_pipe.get_node('PipeInlet').transform.affine_inverse()
	
	# Rotate randomly from 0-270deg in 90deg increments
	instanced_pipe.rotate_object_local(Vector3(0,1,0), (randi() % 4) * 90 * (PI/180))
	
	# Validation - can I place this here? Otherwise, try again
	if (instanced_pipe.get_node('PipeOutlet').global_transform.origin.x < worldBounds.x && instanced_pipe.get_node('PipeOutlet').global_transform.origin.x > -worldBounds.x) && (instanced_pipe.get_node('PipeOutlet').global_transform.origin.y < worldBounds.y && instanced_pipe.get_node('PipeOutlet').global_transform.origin.y > -worldBounds.y) && (instanced_pipe.get_node('PipeOutlet').global_transform.origin.z < worldBounds.z && instanced_pipe.get_node('PipeOutlet').global_transform.origin.z > -worldBounds.z):
		previousPipe = instanced_pipe
		print("Placed pipe!")
		# reset so each 'stuck' situation can try to recur 10 times
		recursions = 0
		pipeCount += 1
		
		if (pipeCount > pipeCountToTriggerColorChange):
			print ("SWAPPING PIPE COLORS")
			var newMat = pipeMaterial.duplicate(true)
			newMat.albedo_color = (Color(randf(),randf(),randf()))
			pipeMaterial = newMat
			pipeCount=0
			
		$Timer.start()
		return 
	elif recursions < recursionLimit:
		print("Self-solving boundary issue...")
		instanced_pipe.queue_free()
		recursions+= 1
		return _pipeStep()
	else:
		print("Limit reached - no more placements possible")
		
	
func _on_timer_timeout():
	#TODO - Separate spawn points for different colored pipes to get screen coverage faster
	#TODO - Make it run for a certain amount of time before dissolving and restarting, as a complete loop
	#TODO - Pixelate-to-black dissolve shader for transitions
	#TODO - Export to Wallpaper Engine and put on Steam Workshop
	_pipeStep()
