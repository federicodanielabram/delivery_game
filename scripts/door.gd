extends StaticBody2D

func open_door() -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	$Visual.modulate.a = 0.0
