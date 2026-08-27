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
## Prazo por NIVEL, zerado a cada avanco de campanha - nao por execucao.
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
			# O prazo e POR NIVEL. Sem este reset a campanha inteira dividia os
			# 420s: com 9 niveis, o nivel 8 comecava a rodada com 60s de sobra e
			# "estourava o tempo" jogando perfeitamente bem.
			_elapsed = 0.0
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
		# Aqui a exigencia e OUTRA: esta colmeia ja esta na mesa e sem alvo.
		# Levar ela pra um ponto que cobre alguma coisa e sempre melhor que
		# deixar em cima de nada - pedir que cubra todas as abelhas dela
		# congelava o fim de nivel, quando so restam migalhas espalhadas. Quem
		# decide se vale gastar o remanejamento e a regra de ganho minimo logo
		# abaixo, nao o corte de capacidade.
		var spot := _best_spot(h.color_key, h.radius_cells, h.territorial, h,
			h.moves_allowed >= 0, 0)
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
	# Pilhas com mais bloco exposto primeiro - mas uma pilha cujo topo nao tem
	# onde pousar nao pode travar as outras. Com colmeias presas isso acontece o
	# tempo todo no comeco, quando a imagem ainda esta fechada.
	var ordem: Array = []
	for j in game.columns.size():
		if not (game.columns[j] as Array).is_empty():
			ordem.append(j)
	if ordem.is_empty():
		return
	ordem.sort_custom(func(a, b):
		var ea: int = game.board.frontier_of(str(game.columns[a][0]["color"])).size()
		var eb: int = game.board.frontier_of(str(game.columns[b][0]["color"])).size()
		return ea > eb)

	for j in ordem:
		var spec: Dictionary = game.columns[j][0]
		var mov: int = int(spec.get("moves", -1))
		var fixa: bool = mov == 0
		var terr: bool = bool(spec.get("territorial", false))
		var reach: float = float(spec["radius"]) * game.cell_size
		var spot := _best_spot(str(spec["color"]), float(spec["radius"]),
			terr, null, mov >= 0, int(spec["bees"]) if fixa else 0)
		if spot.x < INF:
			game.place_from_deck(j, spot)
			return
		# Colmeia PRESA sem ponto que caiba as abelhas dela: esperar a imagem
		# abrir e melhor que plantar e encalhar. Estaciona so a carta de cor ja
		# extinta, que e lastro e precisa sair pra coluna andar.
		if fixa:
			if game.board.count_of(str(spec["color"])) == 0:
				var pk := _any_spot(reach, terr)
				if pk.x < INF:
					game.place_from_deck(j, pk)
					return
			continue
		# Colmeia livre: queimar um slot pra desenterrar e jogada legitima - ela
		# espera parada ate a cor dela vir a tona e depois se reposiciona. Tirar
		# esta valvula travava os niveis de cor enterrada.
		var pk2 := _any_spot(reach, terr)
		if pk2.x < INF:
			game.place_from_deck(j, pk2)
			return
	return


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
## Colmeia PRESA precisa de mais que "o melhor ponto": precisa de um ponto que
## caiba TODAS as abelhas dela. Ponto que alcanca 2 blocos nao serve a uma
## colmeia de 7 - ela come os 2 e encalha com 5 dentro, o que desde a regra do
## encalhe e derrota na hora. Por isso, quando `durable`, a busca desconta o que
## as colmeias ja em campo vao consumir e recusa ponto insuficiente.
##
## Para colmeia de reposicionamento livre nada disso vale: ela se corrige depois,
## e exigir perfeicao no pouso so a paralisava.
## `bees > 0` so e exigido de colmeia FIXA (moves == 0). Colmeia com 1, 2 ou 3
## remanejamentos ainda se corrige depois: cobrar dela um pouso perfeito
## congelava o fim de nivel, quando so restam migalhas espalhadas.
func _best_spot(color_key: String, radius_cells: float, territorial := false,
		ignore = null, durable := false, bees := 0) -> Vector2:
	var alvo: Array = _cells_of(color_key) if durable else game.board.frontier_of(color_key)
	if alvo.is_empty():
		return Vector2(INF, INF)
	# Com a imagem ainda fechada, uma cor enterrada nao tem fronteira nenhuma -
	# entao as sementes de busca passam a ser as celulas da cor, e a colmeia
	# planta sobre onde a cor VAI aflorar.
	var sementes: Array = game.board.frontier_of(color_key)
	if sementes.is_empty():
		sementes = alvo

	var tomado := {}
	if bees > 0:
		for h in game.hives:
			if h == ignore or h.color_key != color_key or h.bees_left <= 0:
				continue
			var raio: float = h.radius_cells * game.cell_size
			var perto := []
			for cell in alvo:
				var d: float = h.pos.distance_to(game.cell_center(cell))
				if d <= raio:
					perto.append([d, cell])
			perto.sort_custom(func(a, b): return a[0] < b[0])
			for n in mini(h.bees_left, perto.size()):
				tomado[perto[n][1]] = true

	var reach: float = radius_cells * game.cell_size
	var best := Vector2(INF, INF)
	var best_score := -1
	var step: int = maxi(1, sementes.size() / 24)

	for k in range(0, sementes.size(), step):
		var center: Vector2 = game.cell_center(sementes[k])
		for cand in _candidates(center, reach):
			if not game.can_place_at(cand, reach, territorial, ignore):
				continue
			var score := _score_at(cand, color_key, reach, tomado)
			if score > best_score:
				best_score = score
				best = cand
			break
	if bees > 0 and best_score < bees:
		return Vector2(INF, INF)
	return best


## Quantos blocos de `key` a colmeia pegaria pousando em `at`. Varre so as
## celulas dentro da caixa do raio: percorrer todas as celulas da cor (o ceu tem
## centenas) vezes ~2000 candidatos por decisao deixava o bot lento demais.
func _score_at(at: Vector2, key: String, reach: float, tomado: Dictionary) -> int:
	var cols: int = game.board.cols
	var rows: int = game.board.rows
	var span: int = int(ceil(reach / game.cell_size)) + 1
	var c0: int = int((at.x - game.board_origin.x) / game.cell_size)
	var r0: int = int((at.y - game.board_origin.y) / game.cell_size)
	var n := 0
	for r in range(maxi(0, r0 - span), mini(rows, r0 + span + 1)):
		for c in range(maxi(0, c0 - span), mini(cols, c0 + span + 1)):
			var i: int = r * cols + c
			if game.board.cells[i] == BFBoard.EMPTY or tomado.has(i):
				continue
			if game.board.key_at(i) != key:
				continue
			if at.distance_to(game.cell_center(i)) <= reach:
				n += 1
	return n


func _candidates(center: Vector2, reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = [center]
	# No comeco do nivel o tabuleiro esta inteiro cheio e a unica faixa que
	# aceita colmeia e o anel de folga em volta da imagem. Com dois raios de anel
	# quase todo candidato caia dentro da silhueta e era recusado.
	for ring in [0.3, 0.5, 0.7, 0.9, 1.1]:
		for i in 16:
			var a := float(i) * TAU / 16.0
			out.append(center + Vector2(cos(a), sin(a)) * reach * ring)
	return out


func _deck_left() -> int:
	var n := 0
	for deck in game.columns:
		n += (deck as Array).size()
	return n
