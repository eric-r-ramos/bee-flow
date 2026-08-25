class_name BFAutoplay
extends Node

## Jogador automatico, usado como teste de fumaca do loop inteiro.
##
##     godot --headless --path . --fixed-fps 120 -- --autoplay
##
## Coloca colmeias, desencalha as que ficaram sem alvo e sai com codigo 0 se o
## nivel foi limpo, 1 se travou ou estourou o tempo. Como o gerador so publica
## nivel verificadamente solucionavel, uma derrota aqui e bug de regra no jogo,
## nao azar.

const STEP_INTERVAL := 0.12
const TIMEOUT_SECONDS := 420.0
const HEARTBEAT := 5.0

var game: Node

var _clock := 0.0
var _elapsed := 0.0
var _beat := 0.0
var _done := false


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS:
		_finish("TIMEOUT", 1)
		return
	if game.state == game.State.WON:
		if game.has_next():
			print("[autoplay] nivel %d limpo, avancando" % (game.level_index + 1))
			game.advance()
			return
		_finish("VITORIA", 0)
		return
	if game.state == game.State.LOST:
		_finish("DERROTA", 1)
		return

	_beat += delta
	if _beat >= HEARTBEAT:
		_beat = 0.0
		print("[autoplay] t=%.0fs blocos=%d slots_livres=%d colmeias=%d deck=%d"
			% [_elapsed, game.board.filled_total, game.free_slots(), game.hives.size(),
				_deck_left()])

	_clock += delta
	if _clock < STEP_INTERVAL:
		return
	_clock = 0.0
	_unstick()
	_place_next()


func _finish(label: String, code: int) -> void:
	_done = true
	print("[autoplay] %s  mel=%d  abelhas=%d  blocos_restantes=%d  tempo=%.1fs"
		% [label, game.honey, game.bees_dispatched, game.board.filled_total, _elapsed])
	game.get_tree().quit(code)


## Colmeia parada com abelhas sobrando e sem alvo no alcance: leva ela ate onde
## ainda ha bloco da cor dela. E exatamente o que o jogador faz com o dedo.
func _unstick() -> void:
	for h in game.hives:
		if h.bees_left <= 0 or h.in_flight > 0 or not h.can_move():
			continue
		if game.pick_target(h) >= 0:
			continue
		var spot := _best_spot(h.color_key, h.radius_cells)
		if spot.x < INF:
			h.pos = spot
			h.moves_used += 1


func _place_next() -> void:
	if game.free_slots() == 0:
		return
	var best_j := -1
	var best_n := -1
	for j in game.columns.size():
		var deck: Array = game.columns[j]
		if deck.is_empty():
			continue
		var exposed: int = game.board.frontier_of(str(deck[0]["color"])).size()
		if exposed > best_n:
			best_n = exposed
			best_j = j
	if best_j < 0:
		return
	var spec: Dictionary = game.columns[best_j][0]
	var spot := _best_spot(str(spec["color"]), float(spec["radius"]))
	if spot.x == INF:
		return   # cor ainda enterrada: espera outra colmeia abrir caminho
	game.place_from_deck(best_j, spot)


## Melhor ponto de pouso: o que cobre mais blocos daquela cor sem cair em cima
## de bloco nenhum.
func _best_spot(color_key: String, radius_cells: float) -> Vector2:
	var frontier: Array = game.board.frontier_of(color_key)
	if frontier.is_empty():
		return Vector2(INF, INF)

	var reach: float = radius_cells * game.cell_size
	var best := Vector2(INF, INF)
	var best_score := -1
	var step: int = maxi(1, frontier.size() / 24)

	for k in range(0, frontier.size(), step):
		var center: Vector2 = game.cell_center(frontier[k])
		for cand in _candidates(center, reach):
			if not game.can_place_at(cand):
				continue
			var score := 0
			for cell in frontier:
				if cand.distance_to(game.cell_center(cell)) <= reach:
					score += 1
			if score > best_score:
				best_score = score
				best = cand
			break
	return best


func _candidates(center: Vector2, reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = [center]
	for ring in [0.45, 0.8]:
		for i in 8:
			var a := float(i) * TAU / 8.0
			out.append(center + Vector2(cos(a), sin(a)) * reach * ring)
	return out


func _deck_left() -> int:
	var n := 0
	for deck in game.columns:
		n += (deck as Array).size()
	return n
