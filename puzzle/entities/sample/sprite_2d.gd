extends Sprite2D


var blocks: Array[Block]
@export var block_data: Array[BlockData]


func _ready() -> void:
	for data in block_data:
		var block := Utils.construct_block(data)
		block.function = Callable(self, data.method)
		blocks.append(block)

## text: MOVE [up/down/left/right]
func move(from_this: Block) -> Utils.Result:
	const dir_to_vec := {
		up = Vector2.UP,
		down = Vector2.DOWN,
		left = Vector2.LEFT,
		right = Vector2.RIGHT,
	}
	
	var result := Utils.evaluate_and_check_arguments(1, from_this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	var direction := args[0] as String
	position += dir_to_vec[direction] * get_rect().size * scale
	
	return Utils.Result.success()
