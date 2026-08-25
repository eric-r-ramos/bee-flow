class_name BFTableView
extends Node2D

## Desenha tudo que nao e bloco nem abelha: zona de voo, colmeias plantadas com
## seus raios, a fileira de slots e as pilhas de colmeias disponiveis.

enum Layer { BOARD, UI }

## BOARD desenha zona de voo, raios e colmeias plantadas (fica sob as abelhas).
## UI desenha a faixa opaca de baixo com slots e pilhas (fica sobre tudo), pra
## que um raio grande nao vaze por cima do deck.
var layer := Layer.BOARD
var game: Node

var _font: Font
var _font_size: int


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_font_size = ThemeDB.fallback_font_size


func _draw() -> void:
	if game == null or not game.layout_ready:
		return
	if layer == Layer.BOARD:
		_draw_flight_zone()
		for h in game.hives:
			_draw_radius(h.pos, h.radius_cells * game.cell_size, h.color, h.can_move())
		for h in game.hives:
			_draw_hive(h.pos, h.color, 30.0, "%d" % h.bees_left, h.moves_label())
	else:
		_draw_bottom_band()
		_draw_slots()
		_draw_decks()
		_draw_drag()


# ------------------------------------------------------------------ tabuleiro

func _draw_flight_zone() -> void:
	var area: Rect2 = game.board_area
	draw_rect(area, Color(1, 1, 1, 0.16))
	draw_rect(area, Color(0, 0, 0, 0.08), false, 3.0)


func _draw_radius(center: Vector2, radius: float, color: Color, mobile: bool) -> void:
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.07))
	var edge := Color(color.r, color.g, color.b, 0.5 if mobile else 0.9)
	draw_arc(center, radius, 0.0, TAU, 72, edge, 2.5 if mobile else 5.0)


func _draw_hive(center: Vector2, color: Color, radius: float, bees: String,
		moves: String) -> void:
	# A colmeia e um hexagono: le como favo mesmo em miniatura.
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + float(i) * PI / 3.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, color.darkened(0.4), 3.0)
	_label(Rect2(center - Vector2(radius, radius * 0.55), Vector2(radius * 2.0, radius)),
		bees, int(radius * 0.85), Color(0.12, 0.09, 0.02))
	if moves != "":
		_label(Rect2(center + Vector2(-radius, radius * 0.45), Vector2(radius * 2.0, 22.0)),
			"mov %s" % moves, 20, Color(0.15, 0.12, 0.05))


# ----------------------------------------------------------------- slots/deck

func _draw_bottom_band() -> void:
	var top: float = game.slot_rects[0].position.y - 14.0
	draw_rect(Rect2(0.0, top, game.DESIGN.x, game.DESIGN.y - top),
		Color(0.796, 0.776, 0.729))
	draw_line(Vector2(0.0, top), Vector2(game.DESIGN.x, top), Color(0, 0, 0, 0.12), 3.0)


func _draw_slots() -> void:
	for i in game.slot_rects.size():
		var r: Rect2 = game.slot_rects[i]
		var hive: BFHive = game.slots[i]
		if hive == null:
			draw_rect(r, Color(1, 1, 1, 0.22))
			draw_rect(r, Color(0, 0, 0, 0.16), false, 3.0)
			_label(r, "livre", 26, Color(0.35, 0.32, 0.26), true)
		else:
			draw_rect(r, hive.color.lightened(0.35))
			draw_rect(r, hive.color.darkened(0.35), false, 4.0)
			_draw_hive(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.4),
				hive.color, r.size.y * 0.3, "%d" % hive.bees_left, "")
			_label(Rect2(r.position + Vector2(0, r.size.y - 34.0), Vector2(r.size.x, 30.0)),
				hive.kind, 22, Color(0.2, 0.16, 0.08))


func _draw_decks() -> void:
	for j in game.columns.size():
		var deck: Array = game.columns[j]
		if deck.is_empty():
			continue
		var top: Rect2 = game.column_rects[j]
		var behind: int = min(deck.size(), 5)
		for k in range(behind - 1, 0, -1):
			var r := Rect2(top.position + Vector2(0, float(k) * 24.0), top.size)
			var c: Color = game.color_of(deck[k]).darkened(0.15 + 0.06 * float(k))
			draw_rect(r, c)
			draw_rect(r, Color(0, 0, 0, 0.18), false, 2.0)
		_draw_token(top, deck[0], deck.size())


func _draw_token(r: Rect2, spec: Dictionary, depth: int) -> void:
	var color: Color = game.color_of(spec)
	var limited := int(spec.get("moves", -1)) >= 0
	draw_rect(r, color)
	# Colmeia de mobilidade limitada tem contorno grosso e escuro: o jogador
	# precisa saber ANTES de puxar, senao a punicao vira armadilha.
	draw_rect(r, color.darkened(0.7 if limited else 0.35), false, 7.0 if limited else 4.0)

	# O hexagono cresce com o raio: o jogador le o alcance sem precisar de texto.
	var reach := float(spec["radius"])
	_draw_hive(r.position + Vector2(38.0, 36.0), color.lightened(0.3),
		clampf(reach * 2.8, 13.0, 26.0), "", "")
	_label(Rect2(r.position + Vector2(62.0, 8.0), Vector2(r.size.x - 70.0, 48.0)),
		"%d" % int(spec["bees"]), 40, Color(0.14, 0.1, 0.02))
	_label(Rect2(r.position + Vector2(0.0, r.size.y - 32.0), Vector2(r.size.x, 28.0)),
		str(spec.get("kind", "")), 21, Color(0.2, 0.16, 0.06))
	if limited:
		# Selo escuro no canto: borda grossa sozinha e sutil demais pra decisao
		# mais importante do jogador - saber, ANTES de puxar, que aquela colmeia
		# so pode ser remanejada N vezes.
		var badge := Rect2(r.position + Vector2(6.0, 5.0), Vector2(66.0, 24.0))
		draw_rect(badge, Color(0.14, 0.10, 0.02))
		_label(badge, "mov %d" % int(spec["moves"]), 18, Color(0.94, 0.81, 0.49))
	if depth > 1:
		_label(Rect2(r.position + Vector2(r.size.x - 48.0, 4.0), Vector2(44.0, 24.0)),
			"x%d" % depth, 19, Color(0.2, 0.16, 0.06))


# ------------------------------------------------------------------- arrastar

func _draw_drag() -> void:
	if not game.drag_active:
		return
	var color: Color = game.drag_color()
	var radius: float = game.drag_radius() * game.cell_size
	_draw_radius(game.drag_pos, radius, color, true)
	_draw_hive(game.drag_pos, color, 30.0, "%d" % game.drag_bees(), "")
	var ring := Color(0.25, 0.72, 0.3) if game.drag_valid else Color(0.85, 0.25, 0.2)
	draw_arc(game.drag_pos, 38.0, 0.0, TAU, 40, ring, 5.0)


# --------------------------------------------------------------------- helper

func _label(r: Rect2, text: String, size: int, color: Color, dim := false) -> void:
	if text == "":
		return
	var c := color
	if dim:
		c.a = 0.75
	draw_string(_font, r.position + Vector2(0, r.size.y * 0.78), text,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, c)
