extends CharacterBody2D
# Murciélago: vuela cerca de su posición y persigue al jugador cuando lo ve.
# Tiene la misma "interfaz" que zombi.gd (señal, recibir_golpe, volver_a_casa),
# así que mundo.gd lo trata igual que a los demás enemigos.

signal toco_al_jugador(zombi)

@export var vida = 1
@export var agresivo = true
@export var velocidad_patrulla = 60.0
@export var velocidad_persecucion = 130.0
@export var rango_deteccion = 320.0
@export var rango_pierde = 440.0
@export var fuerza_retroceso = 220.0
@export var tiempo_aturdimiento = 0.4
@export var tiempo_retirada = 1.0

var inicio = Vector2.ZERO
var tiempo = 0.0
var aturdido = 0.0
var retirada = 0.0
var muerto = false
var persiguiendo = false

@onready var contacto = $Contacto
@onready var sprite = $AnimatedSprite2D


func _ready():
	inicio = position
	contacto.body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if muerto:
		return
	tiempo += delta

	if aturdido > 0.0:
		aturdido -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	var jugador = get_tree().get_first_node_in_group("jugador")
	actualizar_persecucion(jugador)

	var objetivo = inicio + Vector2(sin(tiempo) * 60.0, sin(tiempo * 2.0) * 14.0)
	var rapidez = velocidad_patrulla
	if retirada > 0.0:
		retirada -= delta
		objetivo = inicio
		rapidez = velocidad_persecucion
	elif persiguiendo:
		objetivo = jugador.global_position + Vector2(0, -16)
		rapidez = velocidad_persecucion

	var deseada = (objetivo - global_position).limit_length(rapidez)
	velocity = velocity.move_toward(deseada, 500.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 5.0:
		sprite.flip_h = velocity.x > 0.0


func actualizar_persecucion(jugador):
	if jugador == null or not agresivo or jugador.muriendo:
		persiguiendo = false
		return
	var distancia = global_position.distance_to(jugador.global_position)
	if persiguiendo:
		if distancia > rango_pierde:
			persiguiendo = false
	elif distancia <= rango_deteccion:
		persiguiendo = true


func _on_body_entered(body):
	if muerto or aturdido > 0.0 or retirada > 0.0:
		return
	if body.is_in_group("jugador"):
		retirada = tiempo_retirada   # tras tocar, se aleja un momento
		toco_al_jugador.emit(self)


func volver_a_casa():
	if muerto:
		return
	position = inicio
	velocity = Vector2.ZERO
	persiguiendo = false
	aturdido = 0.0
	retirada = 0.0


func recibir_golpe(dir = 1):
	if muerto:
		return
	vida -= 1
	if vida <= 0:
		muerto = true
		set_physics_process(false)
		velocity = Vector2.ZERO
		$CollisionShape2D.set_deferred("disabled", true)
		$Contacto.set_deferred("monitoring", false)
		$Contacto/CollisionShape2D.set_deferred("disabled", true)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25)
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		await tween.finished
		queue_free()
	else:
		aturdido = tiempo_aturdimiento
		retirada = 0.0
		velocity = Vector2(dir * fuerza_retroceso, -60.0)
