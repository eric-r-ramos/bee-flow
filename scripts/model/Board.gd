class_name BFBoard
extends RefCounted

## Estado da imagem que esta sendo desmontada.
##
## Regra central: um bloco so e coletavel se estiver na *fronteira*, ou seja,
## ligado ao lado de fora por um caminho de celulas vazias. Bloco ilhado no
## miolo nao existe pro jogo ate os vizinhos sairem - e e justamente por isso
## que o raio das colmeias nunca precisa alcancar o centro da imagem: a
## silhueta encolhe e o miolo vira fronteira sozinho.

const EMPTY := 0

var rows: int
var cols: int
var cells: PackedByteArray        ## 0 = vazio, senao indice da cor + 1
var color_keys: PackedStringArray ## indice -> chave da paleta ("b", "p", ...)
var colors: PackedColorArray
var filled_total := 0

var _dirty := true
var _frontier: Dictionary = {}    ## chave da cor -> Array[int] de indices
var _counts: Dictionary = {}      ## chave da cor -> quantos restam


func setup(level_rows: int, level_cols: int, grid: Array, palette: Dictionary) -> void:
	rows = level_rows
	cols = level_cols
	color_keys = PackedStringArray()
	colors = PackedColorArray()

	var index_of := {}
	for key in palette.keys():
		color_keys.append(key)
		colors.append(Color(str(palette[key]["color"])))
		index_of[key] = color_keys.size()

	cells = PackedByteArray()
	cells.resize(rows * cols)
	for r in rows:
		var line := str(grid[r])
		for c in cols:
			var ch := line.substr(c, 1)
			cells[r * cols + c] = int(index_of.get(ch, EMPTY))
	_dirty = true
	refresh()


## Recalcula fronteira e contagens. Barato o bastante pra rodar sob demanda em
## tabuleiros deste tamanho; se os niveis crescerem muito, vale trocar por uma
## atualizacao incremental em volta da celula removida.
func refresh() -> void:
	if not _dirty:
		return
	_dirty = false

	var n := rows * cols
	var outside := PackedByteArray()
	outside.resize(n)
	var queue := PackedInt32Array()

	for c in cols:
		for r in [0, rows - 1]:
			var i: int = r * cols + c
			if cells[i] == EMPTY and outside[i] == 0:
				outside[i] = 1
				queue.append(i)
	for r in rows:
		for c in [0, cols - 1]:
			var i: int = r * cols + c
			if cells[i] == EMPTY and outside[i] == 0:
				outside[i] = 1
				queue.append(i)

	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var r := i / cols
		var c := i % cols
		for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nr: int = r + off.x   # off.x = delta de linha
			var nc: int = c + off.y   # off.y = delta de coluna
			if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
				continue
			var j := nr * cols + nc
			if outside[j] == 0 and cells[j] == EMPTY:
				outside[j] = 1
				queue.append(j)

	_frontier = {}
	_counts = {}
	filled_total = 0
	for i in n:
		var v := cells[i]
		if v == EMPTY:
			continue
		filled_total += 1
		var key := color_keys[v - 1]
		_counts[key] = int(_counts.get(key, 0)) + 1

		var r := i / cols
		var c := i % cols
		var exposed := r == 0 or r == rows - 1 or c == 0 or c == cols - 1
		if not exposed:
			for j in [i - cols, i + cols, i - 1, i + 1]:
				if outside[j] == 1:
					exposed = true
					break
		if exposed:
			if not _frontier.has(key):
				_frontier[key] = []
			_frontier[key].append(i)


func remove_cell(i: int) -> void:
	if i < 0 or i >= cells.size() or cells[i] == EMPTY:
		return
	cells[i] = EMPTY
	_dirty = true


func frontier_of(key: String) -> Array:
	refresh()
	return _frontier.get(key, [])


func count_of(key: String) -> int:
	refresh()
	return int(_counts.get(key, 0))


func key_at(i: int) -> String:
	var v := cells[i]
	return "" if v == EMPTY else color_keys[v - 1]


func color_at(i: int) -> Color:
	var v := cells[i]
	return Color.WHITE if v == EMPTY else colors[v - 1]


func is_clear() -> bool:
	refresh()
	return filled_total == 0
