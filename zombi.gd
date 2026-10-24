extends CharacterBody2D

signal toco_al_jugador(zombi)

@export var speed = 40.0
@export var vida = 2
@export var agresivo = false
@export var velocidad_persecucion = 70.0
@export var velocidad_embestida = 160.0
@export var rango_embestida = 140.0
@export var rango_deteccion = 260.0
@export var rango_pierde = 360.0
@export var gravedad = 1200.0
@export var aviso_embestida = 0.18
@export var cooldown_embestida = 1.4
@export var fuerza_retroceso = 180.0
@export var friccion_retroceso = 800.0
@export var tiempo_aturdimiento = 0.5

var inicio = Vector2.ZERO
var direccion = 1
var aturdido = 0.0
var muerto = false
var persiguiendo = false
var cooldown_actual = 0.0
var tiempo_embestida = 0.0
var tiempo_aviso = 0.0

@onready var contacto = $Contacto


func _ready():
	inicio = position
	contacto.body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if muerto:
		return

	if not is_on_floor():
		velocity.y += gravedad * delta
	else:
		velocity.y = 0.0

	if aturdido > 0.0:
		aturdido -= delta
		velocity.x = move_toward(velocity.x, 0.0, friccion_retroceso * delta)
		move_and_slide()
		return

	var jugador = null
	if agresivo:
		jugador = get_tree().get_first_node_in_group("jugador")
	actualizar_persecucion(jugador)

	if persiguiendo:
		perseguir(delta, jugador)
	else:
		patrullar()

	move_and_slide()

	if not persiguiendo and is_on_wall():
		direccion *= -1


func actualizar_persecucion(jugador):
	if jugador == null:
		persiguiendo = false
		return

	var distancia = global_position.distance_to(jugador.global_position)
	if persiguiendo:
		if distancia > rango_pierde or not _tiene_linea_de_vision(jugador):
			persiguiendo = false
			tiempo_aviso = 0.0
			tiempo_embestida = 0.0
			cooldown_actual = 0.0
		return

	if distancia <= rango_deteccion and _tiene_linea_de_vision(jugador):
		persiguiendo = true


func _tiene_linea_de_vision(jugador):
	var espacio = get_world_2d().direct_space_state
	var excluir = [get_rid(), jugador.get_rid()]
	var consulta = PhysicsRayQueryParameters2D.create(global_position, jugador.global_position, 1, excluir)
	return espacio.intersect_ray(consulta).is_empty()


func patrullar():
	velocity.x = speed * direccion


func perseguir(delta, jugador):
	if jugador == null:
		velocity.x = 0.0
		return

	var dx = jugador.global_position.x - global_position.x
	var dy = jugador.global_position.y - global_position.y
	if abs(dx) < 1.0:
		velocity.x = 0.0
		return

	direccion = sign(dx)

	if tiempo_aviso > 0.0:
		velocity.x = 0.0
		tiempo_aviso -= delta
		if tiempo_aviso <= 0.0:
			tiempo_embestida = 0.22
			cooldown_actual = cooldown_embestida
		return

	if tiempo_embestida > 0.0:
		velocity.x = direccion * velocidad_embestida
		tiempo_embestida -= delta
		return

	if cooldown_actual > 0.0:
		cooldown_actual -= delta
		velocity.x = direccion * velocidad_persecucion
		return

	if abs(dx) < rango_embestida and abs(dy) < 48.0:
		velocity.x = 0.0
		tiempo_aviso = aviso_embestida
		return

	velocity.x = direccion * velocidad_persecucion


func _on_body_entered(body):
	if muerto or aturdido > 0.0:
		return
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func volver_a_casa():
	if muerto:
		return
	position = inicio
	velocity = Vector2.ZERO
	direccion = 1
	persiguiendo = false
	aturdido = 0.0
	tiempo_aviso = 0.0
	tiempo_embestida = 0.0
	cooldown_actual = 0.0


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
		tiempo_aviso = 0.0
		tiempo_embestida = 0.0
		cooldown_actual = 0.6
		velocity.x = dir * fuerza_retroceso
