class_name BFHive
extends RefCounted

## Uma colmeia em campo.
##
## `radius_cells` e o alcance de voo em celulas: a colmeia so manda abelhas em
## blocos da cor dela dentro desse circulo. `moves_allowed` e a mobilidade -
## -1 significa reposicionamento livre (v0), 0 significa que a colmeia fica
## presa onde foi plantada, e N permite N remanejamentos. E por esse numero que
## a dificuldade vai subir sem mexer em mais nada.

var color_key: String
var color: Color
var kind: String
var radius_cells: float
var bees_total: int
var bees_left: int
var moves_allowed: int
var moves_used := 0
## Colmeia territorial nao divide espaco: nenhuma outra colmeia pousa dentro
## do circulo dela, e ela nao pousa com outra colmeia dentro do circulo dela.
var territorial := false

var pos := Vector2.ZERO
var slot := -1
var in_flight := 0
var spawn_clock := 0.0


static func from_spec(spec: Dictionary, palette: Dictionary) -> BFHive:
	var h := BFHive.new()
	h.color_key = str(spec["color"])
	h.color = Color(str(palette[h.color_key]["color"]))
	h.kind = str(spec.get("kind", "operaria"))
	h.radius_cells = float(spec["radius"])
	h.bees_total = int(spec["bees"])
	h.bees_left = h.bees_total
	h.moves_allowed = int(spec.get("moves", -1))
	h.territorial = bool(spec.get("territorial", false))
	return h


func can_move() -> bool:
	return moves_allowed < 0 or moves_used < moves_allowed


func moves_label() -> String:
	if moves_allowed < 0:
		return ""
	return "%d" % (moves_allowed - moves_used)
