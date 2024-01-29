extends Node

@export_range(2,200)
var gridSize : int = 2

@export var pipeVariants:Array[Pipe]

var grid := []

var lastTilePos : Vector3
var lastTilePipe : Pipe
# Called when the node enters the scene tree for the first time.
func _ready():
	for x in range(gridSize):
		var y_array = []
		for y in range(gridSize):
			var z_array = []
			for z in range(gridSize):
				# Set default value, you can replace this with your desired initialization
				z_array.append(null)
			y_array.append(z_array)
		grid.append(y_array)
	print("Grid calculated")

func _stepPipe():
	if lastTilePipe == null:
		var random_number_1 = randi_range(0, gridSize-1)
		var random_number_2 = randi_range(0, gridSize-1)
		var random_number_3 = randi_range(0, gridSize-1)
		lastTilePos = Vector3(random_number_1, random_number_2, random_number_3)
		lastTilePipe = _chooseRandomPipe()
		grid[lastTilePos.x][lastTilePos.y][lastTilePos.z] = lastTilePipe
		var pipeScene = load(lastTilePipe.prefabPath)
		var instanced_pipe = pipeScene.instantiate()
		add_child(instanced_pipe)
		instanced_pipe.global_position = lastTilePos
		print("Spawned starting pipe")
	else:
		# find the first open connection and try it out
		lastTilePos += lastTilePipe.outlet
		if grid[lastTilePos.x][lastTilePos.y][lastTilePos.z] != null:
			print("Hit end of possible tiles. Bye!")
			return
		
		lastTilePipe = _chooseRandomPipe()
		grid[lastTilePos.x][lastTilePos.y][lastTilePos.z] = lastTilePipe
		var pipeScene = load(lastTilePipe.prefabPath)
		var instanced_pipe = pipeScene.instantiate()
		add_child(instanced_pipe)
		instanced_pipe.global_position = lastTilePos
		print("Spawned connecting pipe")
		#for connection in range(0, lastTilePipe.connections.size()):
		#	if (connection == true):
				
		#print("What else do I do? I am not the start pipe! AY AYAY")

func _chooseRandomPipe():
	var variantIndex = randi() % (pipeVariants.size())
	return pipeVariants[variantIndex]


func _on_timer_timeout():
	_stepPipe()
