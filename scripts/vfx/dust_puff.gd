extends Sprite2D

# Reproduce una secuencia de frames una sola vez y se autodestruye al terminar.
# Uso: puff.call("play", frames_array, fps)

var frames: Array[Texture2D] = []
var fps := 18.0
var frame_index := 0
var frame_timer := 0.0

func play(tex_frames: Array[Texture2D], anim_fps: float = 18.0) -> void:
	frames = tex_frames
	fps = anim_fps
	frame_index = 0
	frame_timer = 0.0
	if frames.size() > 0:
		texture = frames[0]

func _process(delta: float) -> void:
	if frames.is_empty():
		return
	frame_timer += delta
	if frame_timer >= 1.0 / fps:
		frame_timer -= 1.0 / fps
		frame_index += 1
		if frame_index >= frames.size():
			queue_free()
			return
		texture = frames[frame_index]
