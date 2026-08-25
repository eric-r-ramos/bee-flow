class_name BFMapView
extends Node2D

## A rota: os níveis como um caminho de favos, do primeiro embaixo ao último
## em cima. Nível limpo pode ser rejogado; o seguinte só abre depois dele.

const NODE_R := 86.0

var game: Node

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _draw() -> void:
	if game == null or game.map_nodes.is_empty():
		return

	var nodes: Array = game.map_nodes

	# Trilha entre os favos, e um trecho subindo do último para dizer, sem
	# prometer nada, que o caminho continua.
	for i in range(nodes.size() - 1):
		_link(nodes[i], nodes[i + 1], game.is_unlocked(i + 1))
	var last: Vector2 = nodes[nodes.size() - 1]
	_dotted(last + Vector2(0, -NODE_R - 12.0), last + Vector2(0, -NODE_R - 150.0), false)

	for i in nodes.size():
		_node(i, nodes[i])


## Liga dois favos em L: sobe reto e depois atravessa. Uma reta diagonal
## passaria bem por cima do nome do nível de destino, que fica logo abaixo dele.
func _link(from: Vector2, to: Vector2, lit: bool) -> void:
	var corner := Vector2(from.x, to.y)
	_dotted(from + Vector2(0, -NODE_R - 12.0), corner, lit)
	var side := signf(to.x - from.x)
	_dotted(corner, to - Vector2(side * (NODE_R + 12.0), 0.0), lit)


func _dotted(from: Vector2, to: Vector2, lit: bool) -> void:
	var span := from.distance_to(to)
	if span < 20.0:
		return
	var dir := (to - from) / span
	var tone := Color(0.62, 0.45, 0.14, 0.9) if lit else Color(0.55, 0.50, 0.42, 0.35)
	var steps := maxi(int(span / 34.0), 1)
	for k in range(steps + 1):
		draw_circle(from + dir * (span * float(k) / float(steps)),
			6.0 if lit else 5.0, tone)


func _node(index: int, center: Vector2) -> void:
	var cleared: bool = game.is_cleared(index)
	var unlocked: bool = game.is_unlocked(index)
	var info: Dictionary = game.catalog[index]

	var fill := Color(0.55, 0.52, 0.46)
	if cleared:
		fill = Color(0.85, 0.66, 0.24)
	elif unlocked:
		fill = Color(0.96, 0.84, 0.50)

	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + float(i) * PI / 3.0
		pts.append(center + Vector2(cos(a), sin(a)) * NODE_R)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, fill.darkened(0.4), 5.0)

	if unlocked:
		_text(center + Vector2(0, 14), "%d" % (index + 1), 58, Color(0.16, 0.11, 0.03))
	else:
		# Cadeado desenhado: corpo + arco.
		draw_rect(Rect2(center + Vector2(-22, -6), Vector2(44, 38)), Color(0.28, 0.25, 0.20))
		draw_arc(center + Vector2(0, -6), 16.0, PI, TAU, 20, Color(0.28, 0.25, 0.20), 8.0)

	if cleared:
		# Selo de concluído, encostado no favo.
		var seal := center + Vector2(NODE_R * 0.72, -NODE_R * 0.72)
		draw_circle(seal, 26.0, Color(0.29, 0.55, 0.22))
		draw_polyline(PackedVector2Array([
			seal + Vector2(-11, 0), seal + Vector2(-3, 9), seal + Vector2(12, -9)
		]), Color(1, 1, 1), 6.0)

	var label_at := center + Vector2(0, NODE_R + 42.0)
	if unlocked:
		_text(label_at, str(info.get("name", "")), 34, Color(0.22, 0.17, 0.08))
		var band := str(info.get("band", ""))
		var honey: int = game.progress.best_honey(str(info.get("id", "")))
		var sub := band if honey <= 0 else "%s  ·  recorde %d de mel" % [band, honey]
		_text(label_at + Vector2(0, 34), sub, 26, Color(0.42, 0.35, 0.22))
	else:
		_text(label_at, "vença o nível %d" % index, 27, Color(0.45, 0.41, 0.34))


func _text(at: Vector2, s: String, size: int, color: Color) -> void:
	draw_string(_font, at - Vector2(400.0, 0.0), s, HORIZONTAL_ALIGNMENT_CENTER,
		800.0, size, color)
