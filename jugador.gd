extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar
@onready var sonido_muerte = $Muerte

var rodando = false
var mirando = 1
var inicio = Vector2.ZERO
var muriendo = false


func _ready():
	inicio = position


func _physics_process(delta):
	if muriendo:
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
		golpe.position.x = 36 * mirando

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false
	
func atacar():
	if muriendo:
		return
	var hueso = $Golpe/Hueso
	hueso.visible = true
	hueso.rotation = 0.0
	espada.play()
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hueso, "rotation", -0.7, 0.08)   # amague hacia atrás
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(hueso, "rotation", 1.1, 0.12)    # golpe hacia adelante
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(hueso, "rotation", 0.0, 0.10)    # regresa
	await espada.finished
	hueso.visible = false


func morir(reaparecer := true):
	if muriendo:
		return
	muriendo = true
	rodando = false
	velocity = Vector2.ZERO
	$Golpe/Hueso.visible = false
	sprite.speed_scale = 1
	sprite.play("morir")
	sonido_muerte.play()
	await sprite.animation_finished
	if reaparecer:
		position = inicio
		sprite.play("quieto")
		muriendo = false
