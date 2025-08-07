extends Sprite2D


const dir_to_vec := {
	up = Vector2.UP,
	down = Vector2.DOWN,
	left = Vector2.LEFT,
	right = Vector2.RIGHT,
}

var blocks: Array[Block]
@export var block_data: Array[BlockData]


func _ready() -> void:
	for data in block_data:
		var block := Utils.construct_block(data)
		block.function = Callable(self, data.method).bind(block)
		blocks.append(block)

## text: MOVE [up/down/left/right]
func move(from_this: Block) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(1, from_this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	var direction := args[0] as String
	position += dir_to_vec[direction] * get_rect().size * scale
	
	return Utils.Result.success()
