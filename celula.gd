extends Area2D

@export var valor = 1


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		print("recogida: +", valor)
		queue_free()
