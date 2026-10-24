extends Area2D

signal toco_al_jugador(zombi)

@export var speed = 40.0

var inicio_x = 0.0
var direccion = 1


func _ready():
	inicio_x = position.x
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	position.x += speed * direccion * delta
	if position.x > inicio_x + 32.0:
		direccion = -1
	elif position.x < inicio_x - 32.0:
		direccion = 1


func _on_body_entered(body):
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func volver_a_casa():
	position.x = inicio_x
	direccion = 1
