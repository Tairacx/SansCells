extends "res://bloques.gd"
# Base del Taller 4. construir() arma el nivel a partir del MAPA:
# "#" bloque, "." moneda, "o" pergamino, "E" zombi (zona 1) / esqueleto (zona 2), "B" murcielago.
# La zona 2 empieza en la columna ZONA2_COL (bloques.gd): cambian el fondo y los enemigos.

const MAPA = [
	"                                                                                                              ",
	"                                                                                                              ",
	"                                                                                                              ",
	"#                                           B                                         B                   B  #",
	"#           B                   B                                 B           B o               B            #",
	"#                                       o                                      .#.                           #",
	"#                        .E.           .#.                 . .          o.     ###                   .E.     #",
	"#              .        #####         #####                 ###               #####        ##        ###     #",
	"#   .  . E.   ### ..E ##  ..  . E.  ######### . E ### .   ###  E. ## .E   . ######### ..E ###    .E.#####  o #",
	"########################################################################  ####################  ##############",
]

var moneda_escena = preload("res://moneda.tscn")
var pergamino_escena = preload("res://pergamino.tscn")
var zombi_escena = preload("res://zombi.tscn")
var esqueleto_escena = preload("res://esqueleto.tscn")
var murcielago_escena = preload("res://murcielago.tscn")

@onready var jugador = $Prisionero
@onready var fondo_cerca = $FondoCerca
@onready var fondo_lejano2 = $FondoLejano2
@onready var fondo_cerca2 = $FondoCerca2

var puntaje = 0
var modo_poder = false
var restantes = 0
var vidas = 3
var juego_terminado = false
var mezcla = 0.0            # 0 = fondo de la zona 1, 1 = fondo de la zona 2
var zona2_alcanzada = false


func _ready():
	construir()
	configurar_camara()
	restantes = get_tree().get_nodes_in_group("monedas").size()
	for item in get_tree().get_nodes_in_group("monedas"):
		item.recogido.connect(_on_recogido)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.toco_al_jugador.connect(_on_enemigo_toco)
	jugador.golpeo.connect(_on_jugador_golpeo)
	$TimerPoder.timeout.connect(_on_timer_poder_timeout)
	$HUD/Vidas.text = "Vidas: %d" % vidas


func _on_recogido(valor, da_poder):
	puntaje += valor
	$HUD/Puntaje.text = "Puntaje: %d" % puntaje
	restantes -= 1
	if restantes == 0:
		$HUD/Mensaje.text = "¡Bioma limpio!"
		juego_terminado = true
	if da_poder:
		modo_poder = true
		$TimerPoder.start()
		print("poder: sí")


func _on_timer_poder_timeout():
	modo_poder = false
	print("poder: no")


func _on_enemigo_toco(enemigo):
	if jugador.muriendo or jugador.rodando or juego_terminado:
		return
	if modo_poder:
		enemigo.volver_a_casa()
		puntaje += 200
		$HUD/Puntaje.text = "Puntaje: %d" % puntaje
	else:
		perder_vida()


func perder_vida():
	vidas -= 1
	if vidas <= 0:
		vidas = 0
		juego_terminado = true
		$HUD/Mensaje.text = "Perdiste"
		jugador.morir(false)
		jugador.set_physics_process(false)
	else:
		jugador.morir()
	$HUD/Vidas.text = "Vidas: %d" % vidas


func _on_jugador_golpeo(zombi):
	if juego_terminado:
		return
	zombi.recibir_golpe(jugador.mirando)


func construir():
	construir_bloques(MAPA)
	for fila in MAPA.size():
		for col in MAPA[fila].length():
			var escena = null
			var terrestre = false
			match MAPA[fila][col]:
				".":
					escena = moneda_escena
				"o":
					escena = pergamino_escena
				"E":
					# zona 1: zombis, zona 2: esqueletos
					escena = zombi_escena if col < ZONA2_COL else esqueleto_escena
					terrestre = true
				"B":
					escena = murcielago_escena
			if escena:
				var nodo = escena.instantiate()
				if terrestre:
					nodo.agresivo = true
					var fila_piso = fila
					while fila_piso + 1 < MAPA.size() and MAPA[fila_piso + 1][col] != "#":
						fila_piso += 1
					nodo.position = Vector2((col + 0.5) * CELDA, (fila_piso + 1) * CELDA - 28.0)
				else:
					nodo.position = Vector2(col + 0.5, fila + 0.5) * CELDA
				$Mapa.add_child(nodo)


# La cámara no se sale del mapa
func configurar_camara():
	var camara = jugador.get_node("Camera2D")
	camara.limit_left = 0
	camara.limit_top = 0
	camara.limit_right = MAPA[0].length() * CELDA
	camara.limit_bottom = MAPA.size() * CELDA


func _process(delta):
	# Cambio de fondo al entrar a la zona 2
	var en_zona2 = jugador.global_position.x >= ZONA2_COL * CELDA
	mezcla = move_toward(mezcla, 1.0 if en_zona2 else 0.0, delta * 1.5)
	fondo_lejano2.modulate.a = mezcla
	fondo_cerca2.modulate.a = mezcla
	fondo_cerca.modulate.a = 1.0 - mezcla
	if en_zona2 and not zona2_alcanzada:
		zona2_alcanzada = true
		jugador.inicio = Vector2((ZONA2_COL + 1.5) * CELDA, 8.5 * CELDA)   # checkpoint
	# Si cae a un foso pierde una vida (reaparece en el último checkpoint)
	if jugador.position.y > MAPA.size() * CELDA + 300 and not jugador.muriendo and not juego_terminado:
		perder_vida()
