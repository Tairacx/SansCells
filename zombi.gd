extends Area2D

signal toco_al_jugador(zombi)

@export var speed = 40.0
@export var vida = 2
@export var agresivo = false
@export var velocidad_persecucion = 70.0
@export var velocidad_embestida = 220.0
@export var rango_embestida = 140.0

var inicio_x = 0.0
var direccion = 1
var aturdido = false
var muerto = false
var cooldown_embestida = 0.0
var tiempo_embestida = 0.0


func _ready():
	inicio_x = position.x
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if muerto or aturdido:
		return
	if agresivo:
		perseguir(delta)
		return
	position.x += speed * direccion * delta
	if position.x > inicio_x + 32.0:
		direccion = -1
	elif position.x < inicio_x - 32.0:
		direccion = 1


func perseguir(delta):
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	var dx = jugador.global_position.x - global_position.x
	if abs(dx) < 1.0:
		return
	direccion = sign(dx)
	if tiempo_embestida > 0.0:
		position.x += direccion * velocidad_embestida * delta
		tiempo_embestida -= delta
	elif cooldown_embestida > 0.0:
		cooldown_embestida -= delta
		position.x += direccion * speed * delta
	elif abs(dx) < rango_embestida and abs(jugador.global_position.y - global_position.y) < 48.0:
		tiempo_embestida = 0.22
		cooldown_embestida = 1.2
	else:
		position.x += direccion * velocidad_persecucion * delta


func _on_body_entered(body):
	if muerto or aturdido:
		return
	if body.is_in_group("jugador"):
		toco_al_jugador.emit(self)


func volver_a_casa():
	position.x = inicio_x
	direccion = 1


func recibir_golpe(dir = 1):
	if muerto:
		return
	vida -= 1
	if vida <= 0:
		muerto = true
		set_physics_process(false)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		$CollisionShape2D.set_deferred("disabled", true)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25)
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		await tween.finished
		queue_free()
	else:
		aturdido = true
		var tween = create_tween()
		tween.tween_property(self, "position:x", position.x + dir * 24.0, 0.12)
		await get_tree().create_timer(0.3).timeout
		aturdido = false
