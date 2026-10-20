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


func _ready():
	construir()


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
