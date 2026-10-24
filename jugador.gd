extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

signal golpeo(zombi)

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var hueso = $Golpe/Hueso
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar
@onready var sonido_muerte = $Muerte

var rodando = false
var mirando = 1
var inicio = Vector2.ZERO
var muriendo = false
var atacando = false
var golpeados = {}


func _ready():
	inicio = position
	golpe.monitoring = false
	hueso.visible = false
	golpe.body_entered.connect(_on_golpe_body_entered)


func _physics_process(delta):
	if muriendo:
		return
	if atacando:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if rodando:
		velocity.x = velocidad_rodar * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		atacar()
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 22 * mirando
		hueso.flip_h = mirando == -1

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false
	
func atacar():
	if muriendo or atacando or rodando:
		return
	atacando = true
	golpeados.clear()
	hueso.visible = true
	sprite.speed_scale = 1
	sprite.play("atacar")
	espada.play()
	await get_tree().create_timer(0.10).timeout
	if not atacando or muriendo:
		hueso.visible = false
		return
	golpe.monitoring = true
	await get_tree().physics_frame
	if not atacando or muriendo:
		golpe.monitoring = false
		hueso.visible = false
		return
	for body in golpe.get_overlapping_bodies():
		_golpear(body)
	await get_tree().create_timer(0.22).timeout
	golpe.monitoring = false
	if sprite.is_playing():
		await sprite.animation_finished
	hueso.visible = false
	atacando = false


func _on_golpe_body_entered(body):
	_golpear(body)


func _golpear(body):
	if not atacando or muriendo:
		return
	if not body.is_in_group("enemigos"):
		return
	if golpeados.has(body):
		return
	golpeados[body] = true
	golpeo.emit(body)


func morir(reaparecer := true):
	if muriendo:
		return
	muriendo = true
	rodando = false
	atacando = false
	velocity = Vector2.ZERO
	golpe.set_deferred("monitoring", false)
	hueso.visible = false
	golpeados.clear()
	sprite.speed_scale = 1
	sprite.play("morir")
	sonido_muerte.play()
	await sprite.animation_finished
	if reaparecer:
		position = inicio
		sprite.play("quieto")
		muriendo = false
