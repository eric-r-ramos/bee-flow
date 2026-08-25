extends Node2D

## Bee Flow - loop principal.
##
## O jogador arrasta a colmeia do topo de uma pilha ate um ponto livre da zona
## de voo. Ela ocupa um dos 5 slots e manda abelhas buscarem blocos da cor dela
## dentro do raio. Slot so libera quando a colmeia esvazia (ou quando a cor dela
## acaba no tabuleiro). Acabou a imagem, ganhou; ficou sem movimento, perdeu.

## Ordem da campanha. O jogador avanca ao limpar a imagem.
const LEVELS := [
	"res://levels/level_001.json",
	"res://levels/level_002.json",
	"res://levels/level_003.json",
	"res://levels/level_004.json",
]

## `-- --level res://levels/x.json` fixa um nivel e desliga a progressao,
## que e como os testes rodam um nivel isolado.
static func _forced_level() -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--level")
	if at >= 0 and at + 1 < args.size():
		return args[at + 1]
	return ""

const DESIGN := Vector2(1080.0, 1920.0)
const HUD_H := 170.0
const SLOTS_H := 160.0
const DECK_H := 300.0
const MARGIN_CELLS := 1.6   ## folga em celulas ao redor da imagem: a zona de voo
const SPAWN_INTERVAL := 0.26
const TOKEN := Vector2(170.0, 96.0)
const LANE_X0 := 85.0
const LANE_STEP := 185.0

enum State { PLAYING, WON, LOST }
enum Screen { MAP, GAME }

var level: Dictionary = {}
var level_index := 0
var screen := Screen.MAP
var progress := BFProgress.new()
var catalog: Array = []          ## um resumo por nível, lido no boot
var map_nodes: Array = []        ## centro de cada favo da rota
var board := BFBoard.new()
var columns: Array = []      ## Array[Array[Dictionary]] - indice 0 e o topo
var slots: Array = []        ## BFHive ou null
var hives: Array = []        ## colmeias ativas em campo
var reserved: Dictionary = {}  ## indice da celula -> abelha que ja foi buscar

var honey := 0
var bees_dispatched := 0
var blocks_at_start := 0   ## quantos blocos o nível tinha; o mel final tem que bater
## Instrumentação da mobilidade limitada: sem isso um teste que passa não
## distingue "a mecânica funciona" de "a mecânica nunca foi acionada".
var limited_placed := 0
var limited_exhausted := 0
var state := State.PLAYING

var cell_size := 32.0
var board_origin := Vector2.ZERO
var board_area := Rect2()
var slot_rects: Array[Rect2] = []
var column_rects: Array[Rect2] = []
var layout_ready := false

var drag_active := false
var drag_valid := false
var drag_pos := Vector2.ZERO
var _drag_spec: Dictionary = {}
var _drag_column := -1
var _drag_hive: BFHive = null

var map_view: BFMapView
var _shots: Array = []      ## instantes (s) que ainda faltam capturar
var _shot_prefix := ""
var _shot_n := 0
var _shot_clock := 0.0

var board_view: BFBoardView
var table: BFTableView       ## camada do tabuleiro (sob as abelhas)
var table_ui: BFTableView    ## camada da UI de baixo (sobre as abelhas)
var bee_layer: Node2D
var hud: BFHud


func _ready() -> void:
	board_view = BFBoardView.new()
	add_child(board_view)

	table = BFTableView.new()
	table.game = self
	table.layer = BFTableView.Layer.BOARD
	add_child(table)

	bee_layer = Node2D.new()
	add_child(bee_layer)

	table_ui = BFTableView.new()
	table_ui.game = self
	table_ui.layer = BFTableView.Layer.UI
	add_child(table_ui)

	map_view = BFMapView.new()
	map_view.game = self
	add_child(map_view)

	hud = BFHud.new()
	add_child(hud)
	hud.build(self)

	# `-- --shot /tmp/bf --shot-at 1,4` salva PNGs, em qualquer tela.
	var shot_at := OS.get_cmdline_user_args().find("--shot")
	if shot_at >= 0 and shot_at + 1 < OS.get_cmdline_user_args().size():
		_shot_prefix = OS.get_cmdline_user_args()[shot_at + 1]
	var when := OS.get_cmdline_user_args().find("--shot-at")
	if when >= 0 and when + 1 < OS.get_cmdline_user_args().size():
		for piece in OS.get_cmdline_user_args()[when + 1].split(","):
			_shots.append(float(piece))

	progress.load_from_disk()
	_build_catalog()
	_layout_map()

	# Os testes headless entram direto no jogo; a rota é para o jogador.
	var args := OS.get_cmdline_user_args()
	if "--autoplay" in args or _forced_level() != "":
		open_level(0)
	else:
		go_to_map()

	if "--autoplay" in args:
		var bot: Node = preload("res://scripts/Autoplay.gd").new()
		bot.game = self
		add_child(bot)


# ------------------------------------------------------------------- a rota

func _build_catalog() -> void:
	catalog = []
	for path in LEVELS:
		var data = JSON.parse_string(FileAccess.get_file_as_string(str(path)))
		if typeof(data) != TYPE_DICTIONARY:
			push_error("nível ilegível: %s" % path)
			continue
		var meta: Dictionary = data.get("meta", {})
		var diff = meta.get("difficulty", null)
		catalog.append({
			"id": str(data.get("id", path)),
			"name": str(data.get("name", "?")),
			"band": str(diff["band"]) if typeof(diff) == TYPE_DICTIONARY else "",
		})


func _layout_map() -> void:
	map_nodes = []
	if catalog.is_empty():
		return
	# Primeiro nível embaixo, o caminho sobe alternando os lados. A pilha é
	# centrada: com poucos níveis ela não fica amontoada num canto.
	const SPACING := 320.0
	var total := float(catalog.size() - 1) * SPACING
	var bottom := DESIGN.y * 0.56 + total * 0.5
	for i in catalog.size():
		var x := 360.0 if i % 2 == 0 else 720.0
		map_nodes.append(Vector2(x, bottom - float(i) * SPACING))


func is_cleared(i: int) -> bool:
	return i < catalog.size() and progress.is_cleared(str(catalog[i]["id"]))


## Nível abre quando o anterior foi vencido. O primeiro sempre está aberto.
func is_unlocked(i: int) -> bool:
	return i == 0 or is_cleared(i - 1)


func go_to_map() -> void:
	screen = Screen.MAP
	drag_active = false
	for bee in bee_layer.get_children():
		bee.queue_free()
	_apply_screen()


func open_level(index: int) -> void:
	level_index = clampi(index, 0, LEVELS.size() - 1)
	screen = Screen.GAME
	restart()
	_apply_screen()


func _apply_screen() -> void:
	var playing := screen == Screen.GAME
	map_view.visible = not playing
	board_view.visible = playing
	table.visible = playing
	table_ui.visible = playing
	bee_layer.visible = playing
	hud.set_screen(playing)
	map_view.queue_redraw()


# --------------------------------------------------------------- carga/layout

func restart() -> void:
	for bee in bee_layer.get_children():
		bee.queue_free()
	reserved.clear()
	hives.clear()
	honey = 0
	bees_dispatched = 0
	limited_placed = 0
	limited_exhausted = 0
	state = State.PLAYING
	hud.hide_banner()

	var forced := _forced_level()
	var path: String = forced if forced != "" else str(LEVELS[level_index])
	var raw := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("nivel invalido em %s" % path)
		return
	level = parsed

	board.setup(int(level["rows"]), int(level["cols"]), level["grid"], level["palette"])

	columns = []
	for col in level["columns"]:
		columns.append((col as Array).duplicate(true))

	slots = []
	for i in int(level.get("slots", 5)):
		slots.append(null)

	blocks_at_start = board.filled_total

	_layout()
	board_view.board = board
	board_view.origin = board_origin
	board_view.cell = cell_size
	board_view.queue_redraw()
	table.queue_redraw()
	table_ui.queue_redraw()
	hud.refresh()


func _layout() -> void:
	var board_h := DESIGN.y - HUD_H - 16.0 - SLOTS_H - 24.0 - DECK_H - 20.0
	board_area = Rect2(20.0, HUD_H, DESIGN.x - 40.0, board_h)

	var span := Vector2(board.cols, board.rows) + Vector2.ONE * (MARGIN_CELLS * 2.0)
	cell_size = minf(board_area.size.x / span.x, board_area.size.y / span.y)
	var grid_px := Vector2(board.cols, board.rows) * cell_size
	board_origin = board_area.position + (board_area.size - grid_px) * 0.5

	var slots_y := board_area.position.y + board_area.size.y + 16.0
	var deck_y := slots_y + SLOTS_H + 24.0
	slot_rects.clear()
	column_rects.clear()
	for i in slots.size():
		slot_rects.append(Rect2(LANE_X0 + float(i) * LANE_STEP, slots_y,
			TOKEN.x, SLOTS_H - 10.0))
	for j in columns.size():
		column_rects.append(Rect2(LANE_X0 + float(j) * LANE_STEP, deck_y, TOKEN.x, TOKEN.y))
	layout_ready = true


# ------------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_shot_clock += delta
	if not _shots.is_empty() and _shot_clock >= float(_shots[0]):
		_shots.pop_front()
		_capture()

	if screen != Screen.GAME or state != State.PLAYING:
		return

	for h in hives:
		if h.bees_left <= 0:
			continue
		h.spawn_clock += delta
		if h.spawn_clock < SPAWN_INTERVAL:
			continue
		var target := pick_target(h)
		if target < 0:
			continue   # sem alvo: nao zera o relogio, sai na hora que aparecer um
		h.spawn_clock = 0.0
		h.bees_left -= 1
		h.in_flight += 1
		bees_dispatched += 1
		_spawn_bee(h, target)

	_retire_finished()
	_check_end()
	table.queue_redraw()
	table_ui.queue_redraw()
	hud.refresh()


func _capture() -> void:
	if _shot_prefix == "":
		return
	_shot_n += 1
	var path := "%s_%d.png" % [_shot_prefix, _shot_n]
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[shot] %s" % path)


func _spawn_bee(h: BFHive, cell: int) -> void:
	var bee := BFBee.new()
	bee.game = self
	bee.hive = h
	bee.target_cell = cell
	bee.position = h.pos
	reserved[cell] = bee
	bee_layer.add_child(bee)


## Colmeia sai de campo quando esvazia ou quando a cor dela acaba no tabuleiro -
## e a segunda condicao que permite gerar niveis com folga de abelhas sem que o
## excedente prenda um slot pra sempre.
func _retire_finished() -> void:
	for h in hives.duplicate():
		if h.in_flight > 0:
			continue
		if h.bees_left <= 0 or board.count_of(h.color_key) == 0:
			slots[h.slot] = null
			hives.erase(h)


## Abelhas ainda no ar carregando bloco.
##
## O bloco sai do tabuleiro na COLETA, mas vira mel na ENTREGA. Declarar
## vitória em `board.is_clear()` cortaria o nível no instante da última coleta,
## e as abelhas que ainda estivessem voltando nunca entregariam - o jogador
## veria 400 blocos virarem 398 de mel. O nível acaba quando a última abelha
## pousa, não quando o último bloco some.
func _bees_in_flight() -> int:
	var n := 0
	for h in hives:
		n += h.in_flight
	return n


func _check_end() -> void:
	if board.is_clear() and _bees_in_flight() == 0:
		state = State.WON
		progress.record(str(level.get("id", "?")), honey, bees_dispatched)
		map_view.queue_redraw()
		if has_next():
			hud.show_banner("nivel %d concluido" % (level_index + 1), "proximo nivel")
		else:
			hud.show_banner("todos os niveis concluidos", "jogar de novo")
	elif _is_deadlocked():
		state = State.LOST
		hud.show_banner("sem movimentos", "tentar de novo")


## Progressao so existe quando nenhum nivel foi forcado na linha de comando.
func has_next() -> bool:
	return _forced_level() == "" and level_index + 1 < LEVELS.size()


func advance() -> void:
	if state == State.WON and has_next():
		level_index += 1
	restart()


func _is_deadlocked() -> bool:
	if free_slots() > 0 and _any_deck_left():
		return false
	for h in hives:
		if h.in_flight > 0 or h.bees_left <= 0:
			return false
		if board.count_of(h.color_key) == 0:
			return false   # vai se aposentar e liberar o slot
		if h.can_move():
			# Reposicionavel: basta existir bloco da cor dela em qualquer lugar.
			if not board.frontier_of(h.color_key).is_empty():
				return false
		elif pick_target(h) >= 0:
			return false
	return true


func _any_deck_left() -> bool:
	for col in columns:
		if not (col as Array).is_empty():
			return true
	return false


func free_slots() -> int:
	var n := 0
	for s in slots:
		if s == null:
			n += 1
	return n


# ------------------------------------------------------------------- abelhas

func pick_target(h: BFHive) -> int:
	var best := -1
	var best_d := INF
	var reach := h.radius_cells * cell_size
	for i in board.frontier_of(h.color_key):
		var cell: int = i
		if reserved.has(cell):
			continue
		var d := h.pos.distance_to(cell_center(cell))
		if d <= reach and d < best_d:
			best_d = d
			best = cell
	return best


func is_target_valid(bee: BFBee) -> bool:
	var i := bee.target_cell
	if i < 0 or board.cells[i] == BFBoard.EMPTY:
		return false
	if board.key_at(i) != bee.hive.color_key:
		return false
	return bee.hive.pos.distance_to(cell_center(i)) <= bee.hive.radius_cells * cell_size


func retarget(bee: BFBee) -> bool:
	reserved.erase(bee.target_cell)
	var t := pick_target(bee.hive)
	bee.target_cell = t
	if t < 0:
		return false
	reserved[t] = bee
	return true


func collect(bee: BFBee) -> void:
	reserved.erase(bee.target_cell)
	board.remove_cell(bee.target_cell)
	board_view.queue_redraw()


func deliver(bee: BFBee) -> void:
	bee.hive.in_flight -= 1
	honey += 1
	bee.queue_free()


## Abelha que voltou de mao vazia devolve a vaga: reposicionar a colmeia nunca
## pode custar abelhas ao jogador.
func refund(bee: BFBee) -> void:
	bee.hive.in_flight -= 1
	bee.hive.bees_left += 1
	bee.queue_free()


# ----------------------------------------------------------------- geometria

func cell_center(i: int) -> Vector2:
	var c := i % board.cols
	var r := i / board.cols
	return board_origin + Vector2(float(c) + 0.5, float(r) + 0.5) * cell_size


func cell_at(p: Vector2) -> int:
	var local := p - board_origin
	var c := int(floor(local.x / cell_size))
	var r := int(floor(local.y / cell_size))
	if r < 0 or r >= board.rows or c < 0 or c >= board.cols:
		return -1
	return r * board.cols + c


## A colmeia pousa fora da silhueta da imagem, nunca dentro dela. Nao basta a
## celula estar vazia: ela precisa estar ligada ao lado de fora. Um bolsao de
## vazio cercado de blocos continua sendo "dentro da imagem".
##
## Conforme a imagem some, a area valida cresce sozinha - o que era miolo vira
## lado de fora assim que a casca abre.
func can_place_at(p: Vector2) -> bool:
	if not board_area.has_point(p):
		return false
	var i := cell_at(p)
	if i < 0:
		return true   # fora da grade, dentro da zona de voo
	return board.cells[i] == BFBoard.EMPTY and board.is_outside(i)


## Ponto valido mais proximo do dedo. Em vez de deixar o jogador arrastar pra
## dentro da imagem e recusar no fim, a colmeia desliza pela borda e o solte
## sempre funciona.
func nearest_valid(p: Vector2) -> Vector2:
	if can_place_at(p):
		return p
	var step := maxf(cell_size * 0.4, 6.0)
	for ring in range(1, 41):
		var radius := step * float(ring)
		for k in 20:
			var a := TAU * float(k) / 20.0
			var probe := p + Vector2(cos(a), sin(a)) * radius
			if can_place_at(probe):
				return probe
	return p


func color_of(spec: Dictionary) -> Color:
	return Color(str(level["palette"][str(spec["color"])]["color"]))


# ------------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.MAP:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			_tap_map(get_global_mouse_position())
		return
	if state != State.PLAYING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(get_global_mouse_position())
		else:
			_end_drag(get_global_mouse_position())
	elif event is InputEventMouseMotion and drag_active:
		_track_drag(get_global_mouse_position())
	table_ui.queue_redraw()


func _tap_map(p: Vector2) -> void:
	for i in map_nodes.size():
		if p.distance_to(map_nodes[i]) <= BFMapView.NODE_R and is_unlocked(i):
			open_level(i)
			return


func _begin_drag(p: Vector2) -> void:
	for h in hives:
		if h.can_move() and p.distance_to(h.pos) <= 40.0:
			_drag_hive = h
			_drag_column = -1
			_start_drag(p)
			return
	if free_slots() == 0:
		return
	for j in column_rects.size():
		var deck: Array = columns[j]
		if not deck.is_empty() and (column_rects[j] as Rect2).has_point(p):
			_drag_spec = deck[0]
			_drag_column = j
			_drag_hive = null
			_start_drag(p)
			return


func _start_drag(p: Vector2) -> void:
	drag_active = true
	_track_drag(p)


## Dentro da zona de voo a colmeia gruda no ponto valido mais proximo; fora
## dela o arrasto fica invalido, que e como o jogador cancela.
func _track_drag(p: Vector2) -> void:
	if board_area.has_point(p):
		drag_pos = nearest_valid(p)
		drag_valid = can_place_at(drag_pos)
	else:
		drag_pos = p
		drag_valid = false
	table.queue_redraw()
	table_ui.queue_redraw()
	table_ui.queue_redraw()


func _end_drag(p: Vector2) -> void:
	if not drag_active:
		return
	_track_drag(p)
	drag_active = false
	# Solta no ponto ja grudado, nao no cru do dedo.
	var at := drag_pos
	if drag_valid:
		if _drag_hive != null:
			# Um toque sem arrastar nao pode custar um remanejamento. Abaixo do
			# limiar nada acontece - nem move, nem gasta -, senao daria pra
			# atravessar o tabuleiro de graca em passinhos.
			if _drag_hive.pos.distance_to(at) > cell_size * 0.6:
				_drag_hive.pos = at
				_drag_hive.moves_used += 1
				if not _drag_hive.can_move():
					limited_exhausted += 1
		elif _drag_column >= 0:
			place_from_deck(_drag_column, at)
	_drag_hive = null
	_drag_column = -1
	_drag_spec = {}
	table.queue_redraw()
	table_ui.queue_redraw()


func place_from_deck(j: int, p: Vector2) -> void:
	var slot := slots.find(null)
	if slot < 0:
		return
	var deck: Array = columns[j]
	if deck.is_empty():
		return
	var hive := BFHive.from_spec(deck.pop_front(), level["palette"])
	hive.pos = p
	hive.slot = slot
	slots[slot] = hive
	hives.append(hive)
	if hive.moves_allowed >= 0:
		limited_placed += 1


# Consultado pelo TableView pra desenhar o fantasma que segue o dedo.
func drag_color() -> Color:
	return _drag_hive.color if _drag_hive != null else color_of(_drag_spec)


func drag_radius() -> float:
	return _drag_hive.radius_cells if _drag_hive != null else float(_drag_spec["radius"])


func drag_bees() -> int:
	return _drag_hive.bees_left if _drag_hive != null else int(_drag_spec["bees"])
