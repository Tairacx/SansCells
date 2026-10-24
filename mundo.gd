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

var puntaje = 0
var modo_poder = false
var restantes = 0


func _ready():
	construir()
	restantes = get_tree().get_nodes_in_group("celulas").size()
	for item in get_tree().get_nodes_in_group("celulas"):
		item.recogido.connect(_on_recogido)


func _on_recogido(valor, da_poder):
	puntaje += valor
	$HUD/Puntaje.text = "Puntaje: %d" % puntaje
	restantes -= 1
	if restantes == 0:
		$HUD/Mensaje.text = "¡Bioma limpio!"
	if da_poder:
		modo_poder = true
		print("poder: sí")
		await get_tree().create_timer(8.0).timeout
		modo_poder = false
		print("poder: no")


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
