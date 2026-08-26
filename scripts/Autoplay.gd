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
		# Invariante: todo bloco coletado vira exatamente um mel. Já foi violado
		# uma vez - a vitória era declarada na última COLETA, e as abelhas ainda
		# voltando com bloco nunca entregavam. Não dá para comparar com abelhas
		# despachadas: quem volta de mão vazia é despachada de novo depois, e aí
		# a conta legitimamente difere.
		if game.honey != game.blocks_at_start:
			_finish("MEL NAO BATE: %d de mel para %d blocos"
				% [game.honey, game.blocks_at_start], 1)
			return
		if game.has_next():
			print("[autoplay] nivel %d limpo (limitadas: %d colocadas, %d travaram, %d remanejamentos), avancando"
				% [game.level_index + 1, game.limited_placed, game.limited_exhausted,
					game.limited_moves_spent])
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
	var media := 0.0
	if game.limited_placed > 0:
		media = float(game.limited_moves_spent) / float(game.limited_placed)
	print("[autoplay] colmeias limitadas: %d colocadas, %d travaram, %d remanejamentos gastos (media %.2f por colmeia)"
		% [game.limited_placed, game.limited_exhausted, game.limited_moves_spent, media])
	game.get_tree().quit(code)


## Colmeia parada com abelhas sobrando e sem alvo no alcance: leva ela ate onde
## ainda ha bloco da cor dela. E exatamente o que o jogador faz com o dedo.
func _unstick() -> void:
	# Guardar o último movimento é bom estratégia — até o jogo parar. Se
	# ninguém está coletando e ninguém tem alvo, esperar não traz nada: o
	# preço de gastar mal passa a ser menor que o de nunca gastar. Sem esta
	# cláusula o bot ficou 400 segundos imóvel com 170 blocos na tela.
	var travado := true
	for h in game.hives:
		if h.in_flight > 0 or game.pick_target(h) >= 0:
			travado = false
			break

	for h in game.hives:
		if h.bees_left <= 0 or h.in_flight > 0 or not h.can_move():
			continue
		if game.pick_target(h) >= 0:
			continue
		var spot := _best_spot(h.color_key, h.radius_cells, h.territorial, h,
			h.moves_allowed >= 0)
		if spot.x >= INF:
			continue
		# Com remanejamentos escassos, a exigência para mexer cresce conforme o
		# orçamento encolhe. Com três movimentos dá pra ajustar por pouco; com
		# UM, gastar cedo por um ganho pequeno é o que trava a colmeia para
		# sempre - foi exatamente assim que o bot perdeu o nível 8 na primeira
		# tentativa, com 7 de 24 colmeias limitadas encalhadas.
		if h.moves_allowed >= 0:
			var restante: int = h.moves_allowed - h.moves_used
			var minimo: int = 1 if travado else \
				(2 if restante >= 3 else (5 if restante == 2 else 10))
			if _covered(h, spot) - _covered(h, h.pos) < minimo:
				continue
		h.pos = spot
		h.moves_used += 1
		if h.moves_allowed >= 0:
			game.limited_moves_spent += 1
			if not h.can_move():
				game.limited_exhausted += 1


## Quantos blocos da cor dela a colmeia alcançaria a partir de `at`.
func _covered(h, at: Vector2) -> int:
	var reach: float = h.radius_cells * game.cell_size
	var n := 0
	for cell in game.board.frontier_of(h.color_key):
		if at.distance_to(game.cell_center(cell)) <= reach:
			n += 1
	return n


## Todas as células daquela cor que ainda existem, expostas ou não.
func _cells_of(key: String) -> Array:
	var out := []
	for i in game.board.cells.size():
		if game.board.key_at(i) == key:
			out.append(i)
	return out


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
	var spot := _best_spot(str(spec["color"]), float(spec["radius"]),
		bool(spec.get("territorial", false)), null,
		int(spec.get("moves", -1)) >= 0)
	if spot.x == INF:
		# Nenhum topo de pilha tem bloco exposto. O jogador humano tem que
		# queimar um slot mesmo assim, pra desenterrar - a colmeia espera
		# parada até a cor dela vir à tona. Sem isso o bot trava a si mesmo
		# em níveis com cores muito enterradas.
		if game.board.count_of(str(spec["color"])) <= 0:
			return
		spot = _any_spot(float(spec["radius"]) * game.cell_size,
			bool(spec.get("territorial", false)))
		if spot.x == INF:
			return
	game.place_from_deck(best_j, spot)


## Qualquer ponto livre da zona de voo, pra estacionar uma colmeia que ainda
## não tem o que coletar.
func _any_spot(reach := 0.0, territorial := false) -> Vector2:
	var area: Rect2 = game.board_area
	for fy in [0.06, 0.5, 0.94]:
		for fx in [0.06, 0.5, 0.94]:
			var probe := area.position + Vector2(area.size.x * fx, area.size.y * fy)
			if game.can_place_at(probe, reach, territorial):
				return probe
	return Vector2(INF, INF)


## Melhor ponto de pouso: o que cobre mais blocos daquela cor sem cair em cima
## de bloco nenhum.
## `durable` muda o critério: em vez do que está exposto AGORA, pontua pelo que
## ainda existe daquela cor no tabuleiro inteiro. Colmeia que não pode se mexer
## precisa de um ponto que continue valendo quando a fronteira andar - plantar
## pela fronteira do momento é o que encalhava as limitadas.
func _best_spot(color_key: String, radius_cells: float, territorial := false,
		ignore = null, durable := false) -> Vector2:
	var frontier: Array = game.board.frontier_of(color_key)
	if frontier.is_empty():
		return Vector2(INF, INF)
	var alvo: Array = _cells_of(color_key) if durable else frontier
	if alvo.is_empty():
		return Vector2(INF, INF)

	var reach: float = radius_cells * game.cell_size
	var best := Vector2(INF, INF)
	var best_score := -1
	var step: int = maxi(1, frontier.size() / 24)

	for k in range(0, frontier.size(), step):
		var center: Vector2 = game.cell_center(frontier[k])
		for cand in _candidates(center, reach):
			if not game.can_place_at(cand, reach, territorial, ignore):
				continue
			var score := 0
			for cell in alvo:
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
