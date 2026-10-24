extends "res://bloques.gd"
# Base del Taller 4. construir() arma el nivel a partir del MAPA:
# "#" bloque, "." celula, "o" pergamino, "E" zombi.

const MAPA = [
	"                                        ",
	"                                        ",
	"                                        ",
	"                                        ",
	"            .            .              ",
	"      .              o          .       ",
	"   o                                    ",
	"#      .    #     E     ##   .   E     #",
	"#        .  #     .     ##        .    #",
	"########################################",
]

var celula_escena = preload("res://celula.tscn")
var pergamino_escena = preload("res://pergamino.tscn")
var zombi_escena = preload("res://zombi.tscn")

@onready var jugador = $Prisionero

var puntaje = 0
var modo_poder = false
var restantes = 0
var vidas = 3
var juego_terminado = false


func _ready():
	construir()
	restantes = get_tree().get_nodes_in_group("celulas").size()
	for item in get_tree().get_nodes_in_group("celulas"):
		item.recogido.connect(_on_recogido)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		enemigo.toco_al_jugador.connect(_on_enemigo_toco)
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


func construir():
	construir_bloques(MAPA)
	for fila in MAPA.size():
		for col in MAPA[fila].length():
			var escena = null
			match MAPA[fila][col]:
				".":
					escena = celula_escena
				"o":
					escena = pergamino_escena
				"E":
					escena = zombi_escena
			if escena:
				var nodo = escena.instantiate()
				nodo.position = Vector2(col + 0.5, fila + 0.5) * CELDA
				$Mapa.add_child(nodo)
